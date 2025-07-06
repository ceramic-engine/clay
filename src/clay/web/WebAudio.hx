package clay.web;

#if js

import clay.audio.AudioData;
import clay.audio.AudioFormat;
import clay.audio.AudioHandle;
import clay.audio.AudioInstance;
import clay.audio.AudioSource;
import clay.audio.AudioState;
import clay.buffers.Float32Array;
import clay.buffers.Uint8Array;

typedef AudioWorkletNode = Dynamic;

// New typedefs for bus system
private typedef WebAudioBus = {
    ready:Bool,
    index:Int,
    gainNode:js.html.audio.GainNode,
    ?workletNode:AudioWorkletNode,
    ?silentSource:js.html.audio.ConstantSourceNode,
    volume:Float,
    active:Bool,
    name:String,
    ?parameterValues:Array<Float> // Store current parameter values
}

private typedef WebSound = {
    source: AudioSource,
    handle: AudioHandle,
    instance: AudioInstance,
    bus: Int,

    bufferNode: js.html.audio.AudioBufferSourceNode,
    mediaNode: js.html.audio.MediaElementAudioSourceNode,
    mediaElem: js.html.Audio,

    gainNode: js.html.audio.GainNode,
    panNode: js.html.audio.PannerNode,

    ignoreNextEnded: Int,

    state: AudioState,
    loop: Bool,
    pan: Float,
    pitch: Float,
    timeResume: Float,
    timeResumeAppTime: Float,
    ?timePause: Float,
}

@:allow(clay.audio.AudioInstance)
@:allow(clay.audio.AudioSource)
class WebAudio extends clay.base.BaseAudio {

    static inline var HALF_PI:Float = 1.5707;
    static inline var DEFAULT_BUS:Int = 0;
    public static inline var MAX_WORKLET_PARAMS:Int = 128;

    var suspended:Bool = false;
    var handleSeq:Int = 0;

    var instances:Map<AudioHandle, WebSound>;
    var buffers:Map<AudioSource, js.html.audio.AudioBuffer>;
    var busses:Map<Int, WebAudioBus>;
    var workletModules:Map<String, Bool>;

    var ignoreEndedSoundsTick0:Array<WebSound> = [];
    var ignoreEndedSoundsTick1:Array<WebSound> = [];

    var pendingBusWorkletCallbacks:Array<Array<()->Void>> = [];

    var workletMessageCallbacks:Array<Dynamic> = [];

    public var context(default, null):js.html.audio.AudioContext;
    public var active(default, null):Bool = false;

    function new(app:Clay) {
        super(app);
        instances = new Map();
        busses = new Map();
        workletModules = new Map();
    }

    override function init() {
        initWebAudio();
        createDefaultBus();
    }

    override function tick(delta:Float) {
        for (handle => sound in instances) {
            if (sound.loop) {
                switch sound.state {
                    default:
                    case PLAYING:
                        var time = switch sound.state {
                            case PLAYING: sound.timeResume + (app.timestamp - sound.timeResumeAppTime) * sound.pitch;
                            default: 0.0;
                        }
                        var duration = sound.source.getDuration();
                        if (duration > 0) {
                            if (time >= duration) {
                                emitAudioEvent(END, handle);
                                while (time >= duration) {
                                    time -= duration;
                                    sound.timeResumeAppTime += duration / sound.pitch;
                                }
                            }
                        }
                }
            }
        }

        // Just a way to ensure we don't ignore the
        // next onended event on a sound
        // for more than two ticks
        while (ignoreEndedSoundsTick1.length > 0) {
            var sound = ignoreEndedSoundsTick1.shift();
            if (sound.ignoreNextEnded > 0)
                sound.ignoreNextEnded--;
        }
        while (ignoreEndedSoundsTick0.length > 0) {
            var sound = ignoreEndedSoundsTick0.shift();
            ignoreEndedSoundsTick1.push(sound);
        }
    }

    function initWebAudio(sampleRate:Int = 44100) {
        try {
            context = new js.html.audio.AudioContext({
                sampleRate: 44100
            });
        } catch(err:Dynamic) {
            try {
                context = untyped js.Syntax.code('new window.webkitAudioContext()');
            } catch(err:Dynamic) {
                Log.debug('Audio / webaudio / no AudioContext could be created! No audio loading or playback will be available.');
                return;
            }
        }

        if (context == null)
            throw 'Audio / webaudio / no AudioContext could be created, is the Web Audio API supported?';

        var info =
            'channelCount: ${context.destination.channelCount}, ' +
            'channelCountMode: "${context.destination.channelCountMode}", ' +
            'channelInterpretation: "${context.destination.channelInterpretation}", ' +
            'maxChannelCount: ${context.destination.maxChannelCount}, ' +
            'numberOfInputs: ${context.destination.numberOfInputs}, ' +
            'numberOfOutputs: ${context.destination.numberOfOutputs}';

        Log.debug('Audio / webaudio: $context / sampleRate: ${context.sampleRate} / destination: $info');

        active = true;
    }

    override function shutdown():Void {
        // Clean up all busses
        for (bus in busses) {
            if (bus.workletNode != null) {
                bus.workletNode.disconnect();
            }

            if (bus.silentSource != null) {
                bus.silentSource.stop();
                bus.silentSource.disconnect();
            }

            bus.gainNode.disconnect();
        }
        busses.clear();
        context.close();
    }

    // Bus Management Functions

    function createDefaultBus():Void {
        createBus(DEFAULT_BUS, 1.0);
    }

    public function createBus(index:Int, name:String = "", volume:Float = 1.0):Void {
        if (busses.exists(index)) {
            Log.warning('Audio / Bus $index already exists');
            return;
        }

        var gainNode = context.createGain();
        gainNode.gain.value = volume;
        gainNode.connect(context.destination);

        var bus:WebAudioBus = {
            ready: false,
            index: index,
            gainNode: gainNode,
            workletNode: null,
            silentSource: null,
            volume: volume,
            active: true,
            name: name.length > 0 ? name : 'bus-$index',
            parameterValues: [for (i in 0...MAX_WORKLET_PARAMS) 0.0]
        };

        busses.set(index, bus);
        Log.debug('Audio / Created bus $index: ${bus.name}');
    }

    public function destroyBus(index:Int):Void {
        if (index == DEFAULT_BUS) {
            Log.warning('Audio / Cannot destroy default bus');
            return;
        }

        var bus = busses.get(index);
        if (bus == null) return;

        // Stop all sounds on this bus
        for (handle => sound in instances) {
            if (sound.bus == index) {
                stop(handle);
            }
        }

        // Disconnect and cleanup worklet and silent source
        if (bus.workletNode != null) {
            bus.workletNode.disconnect();
        }

        if (bus.silentSource != null) {
            bus.silentSource.stop();
            bus.silentSource.disconnect();
        }

        bus.gainNode.disconnect();
        busses.remove(index);

        Log.debug('Audio / Destroyed bus $index');
    }

    public function setBusVolume(busIndex:Int, volume:Float):Void {
        var bus = busses.get(busIndex);
        if (bus == null) return;

        bus.volume = volume;
        bus.gainNode.gain.value = volume;
        Log.debug('Audio / Set bus $busIndex volume to $volume');
    }

    public function getBusVolume(busIndex:Int):Float {
        var bus = busses.get(busIndex);
        return bus != null ? bus.volume : 0.0;
    }

    public function setBusActive(busIndex:Int, active:Bool):Void {
        var bus = busses.get(busIndex);
        if (bus == null) return;

        bus.active = active;
        bus.gainNode.gain.value = active ? bus.volume : 0.0;
        Log.debug('Audio / Set bus $busIndex active: $active');
    }

    // Audio Worklet Functions

    public function loadWorkletModule(name:String, url:String, ?callback:(success:Bool)->Void):Void {
        if (workletModules.exists(name)) {
            Log.debug('Audio / Worklet module $name already loaded');
            if (callback != null) callback(true);
            return;
        }

        final promise:js.lib.Promise<Dynamic> = Reflect.field(context, 'audioWorklet').addModule(url).then(function(_) {
            workletModules.set(name, true);
            Log.debug('Audio / Loaded worklet module: $name');
            if (callback != null) callback(true);
        });
        promise.catchError(function(error) {
            Log.error('Audio / Failed to load worklet module $name: $error');
            if (callback != null) callback(false);
        });
    }

    public function attachWorkletToBus(busIndex:Int, workletName:String, ?options:Dynamic, ?onReady:()->Void):Bool {
        var bus = busses.get(busIndex);
        if (bus == null) {
            Log.error('Audio / Bus $busIndex does not exist');
            return false;
        }

        if (!workletModules.exists(workletName)) {
            Log.error('Audio / Worklet module $workletName not loaded');
            return false;
        }

        // Remove existing worklet if any
        if (bus.workletNode != null) {
            bus.workletNode.disconnect();
            // Also disconnect the silent source if it exists
            if (bus.silentSource != null) {
                bus.silentSource.stop();
                bus.silentSource.disconnect();
                bus.silentSource = null;
            }
        }

        try {
            // Create new worklet node
            var workletNode:AudioWorkletNode = js.Syntax.code('new AudioWorkletNode({0}, {1}, {2})', context, workletName, options);

            // Initialize parameters with stored values
            if (bus.parameterValues != null) {
                for (i in 0...MAX_WORKLET_PARAMS) {
                    var param = workletNode.parameters.get('param$i');
                    if (param != null) {
                        param.value = bus.parameterValues[i];
                    }
                }
            }

            // Create a silent constant source to keep the worklet processing
            var silentSource = context.createConstantSource();
            silentSource.offset.value = 0.0; // Silent

            // Create a gain node to sum the bus audio with the silent source
            var sumGain = context.createGain();
            sumGain.gain.value = 1.0;

            // Configure the sumGain to preserve stereo
            sumGain.channelCount = 2;
            sumGain.channelCountMode = js.html.audio.ChannelCountMode.EXPLICIT;
            sumGain.channelInterpretation = js.html.audio.ChannelInterpretation.SPEAKERS;

            // Create a channel merger to ensure the silent source is stereo
            var merger = context.createChannelMerger(2);
            silentSource.connect(merger, 0, 0); // Connect mono to left channel
            silentSource.connect(merger, 0, 1); // Connect mono to right channel

            // Connect the audio chain:
            // 1. Bus gain node -> sumGain
            // 2. Silent source -> merger -> sumGain (stereo)
            // 3. sumGain -> worklet -> destination
            bus.gainNode.disconnect();
            bus.gainNode.connect(sumGain);
            merger.connect(sumGain);
            sumGain.connect(workletNode);
            workletNode.connect(context.destination);

            // Start the silent source to keep worklet active
            silentSource.start();

            bus.workletNode = workletNode;
            bus.silentSource = silentSource; // Store reference for cleanup

            workletNode.port.onmessage = (event) -> {
                switch event?.data?.type {
                    case 'trace': trace(event.data);
                    case 'ready': {
                        bus.ready = true;
                        flushBusWorkletReadyCallbacks(busIndex);
                        if (onReady != null) {
                            onReady();
                            onReady = null;
                            // Reply back to let worklet stop firing ready
                            workletNode.port.postMessage({ type: 'ready' });
                        }
                    }
                    case 'addBusFilterWorklet':
                        var i = workletMessageCallbacks.length - 1;
                        while (i >= 0) {
                            final info = workletMessageCallbacks[i];
                            if (info.type == 'addBusFilterWorklet' && info.bus == event.data.bus && info.filterId == event.data.filterId) {
                                workletMessageCallbacks.splice(i, 1);
                                info.callback();
                            }
                            i--;
                        }
                    case null | _:
                }
            };

            Log.debug('Audio / Attached worklet $workletName to bus $busIndex with stereo silent source');
            return true;

        } catch (error:Dynamic) {
            Log.error('Audio / Failed to create worklet node: $error');
            // Restore direct connection on failure
            bus.gainNode.connect(context.destination);
            return false;
        }
    }

    public function detachWorkletFromBus(busIndex:Int):Void {
        var bus = busses.get(busIndex);
        if (bus == null || bus.workletNode == null || !bus.ready) return;

        // Disconnect worklet and silent source
        bus.workletNode.disconnect();

        if (bus.silentSource != null) {
            bus.silentSource.stop();
            bus.silentSource.disconnect();
            bus.silentSource = null;
        }

        // Restore direct connection
        bus.gainNode.disconnect();
        bus.gainNode.connect(context.destination);
        bus.workletNode = null;

        Log.debug('Audio / Detached worklet from bus $busIndex');
    }

    public function sendMessageToWorklet(busIndex:Int, message:Dynamic):Void {
        var bus = busses.get(busIndex);
        if (bus == null || bus.workletNode == null || !bus.ready) return;

        bus.workletNode.port.postMessage(message);
    }

    function flushBusWorkletReadyCallbacks(busIndex:Int):Void {

        var cbs:Array<()->Void> = pendingBusWorkletCallbacks[busIndex];
        if (cbs != null) {
            pendingBusWorkletCallbacks[busIndex] = null;
            for (i in 0...cbs.length) {
                final cb = cbs[i];
                cb();
            }
        }

    }

    public function scheduleWhenBusWorkletReady(busIndex:Int, ready:()->Void):Void {

        var bus = busses.get(busIndex);
        if (bus == null || bus.workletNode == null || !bus.ready) {
            var cbs:Array<()->Void> = pendingBusWorkletCallbacks[busIndex];
            if (cbs == null) {
                cbs = [];
                pendingBusWorkletCallbacks[busIndex] = cbs;
            }
            cbs.push(ready);
        }
        else {
            ready();
        }

    }

    public function setWorkletParameterWhenReady(busIndex:Int, paramName:String, value:Float):Void {
        var bus = busses.get(busIndex);
        if (bus == null || bus.workletNode == null || !bus.ready) {
            scheduleWhenBusWorkletReady(busIndex, () -> {
                setWorkletParameter(busIndex, paramName, value);
            });
        }
        else {
            setWorkletParameter(busIndex, paramName, value);
        }
    }

    public function setWorkletParameter(busIndex:Int, paramName:String, value:Float):Void {
        var bus = busses.get(busIndex);
        if (bus == null || bus.workletNode == null || !bus.ready) return;

        var param = bus.workletNode.parameters.get(paramName);
        if (param != null) {
            param.value = value;

            // Also store the value if it's one of our numbered parameters
            if (StringTools.startsWith(paramName, 'param')) {
                var index = Std.parseInt(paramName.substr(5));
                if (index != null && index >= 0 && index < MAX_WORKLET_PARAMS) {
                    bus.parameterValues[index] = value;
                }
            }
        }
        else {
            Log.warning('Audio / Unknown worklet parameter named "$paramName" for bus $busIndex');
        }
    }

    public function setWorkletParameterByIndexWhenReady(busIndex:Int, paramIndex:Int, value:Float):Void {
        var bus = busses.get(busIndex);
        if (bus == null || bus.workletNode == null || !bus.ready) {
            scheduleWhenBusWorkletReady(busIndex, () -> {
                setWorkletParameterByIndex(busIndex, paramIndex, value);
            });
        }
        else {
            setWorkletParameterByIndex(busIndex, paramIndex, value);
        }
    }

    public function setWorkletParameterByIndex(busIndex:Int, paramIndex:Int, value:Float):Void {
        if (paramIndex < 0 || paramIndex >= MAX_WORKLET_PARAMS) {
            Log.warning('Audio / Parameter index $paramIndex out of range (0-${MAX_WORKLET_PARAMS-1})');
            return;
        }
        setWorkletParameter(busIndex, 'param$paramIndex', value);
    }

    public function getWorkletParameterByIndex(busIndex:Int, paramIndex:Int):Float {
        if (paramIndex < 0 || paramIndex >= MAX_WORKLET_PARAMS) {
            return 0.0;
        }

        var bus = busses.get(busIndex);
        if (bus == null || bus.parameterValues == null) return 0.0;

        return bus.parameterValues[paramIndex];
    }

    // Core Audio Functions

    inline function soundOf(handle:AudioHandle):WebSound {
        return instances.get(handle);
    }

    function getBusGainNode(busIndex:Int):js.html.audio.GainNode {
        var bus = busses.get(busIndex);
        if (bus == null) {
            Log.debug('Audio / Bus $busIndex does not exist, creating it automatically');
            createBus(busIndex); // Auto-create with default parameters
            bus = busses.get(busIndex);
        }
        return bus.gainNode;
    }

    function playBuffer(data:WebAudioData):js.html.audio.AudioBufferSourceNode {
        var node = context.createBufferSource();
        node.buffer = data.buffer;
        return node;
    }

    function playBufferAgain(handle:AudioHandle, sound:WebSound, startTime:Float) {
        sound.bufferNode = playBuffer(cast sound.source.data);
        sound.bufferNode.playbackRate.value = sound.pitch;
        sound.bufferNode.connect(sound.panNode);
        sound.bufferNode.loop = sound.loop;
        sound.panNode.connect(sound.gainNode);

        // Route to appropriate bus instead of directly to destination
        var busGain = getBusGainNode(sound.bus);
        sound.gainNode.connect(busGain);

        sound.bufferNode.start(0, startTime);
        sound.bufferNode.onended = function() {
            soundEnded(sound);
        };
    }

    function playInstance(
        handle:AudioHandle,
        source:AudioSource,
        inst:AudioInstance,
        data:WebAudioData,
        bufferNode:js.html.audio.AudioBufferSourceNode,
        volume:Float,
        loop:Bool,
        busIndex:Int = DEFAULT_BUS
    ) {
        var gain = context.createGain();
        var pan = context.createPanner();
        var node: js.html.audio.AudioNode = null;

        gain.gain.value = volume;
        pan.panningModel = js.html.audio.PanningModelType.EQUALPOWER;
        pan.setPosition(Math.cos(-1 * HALF_PI), 0, Math.sin(1 * HALF_PI));

        if (bufferNode != null) {
            node = bufferNode;
            bufferNode.loop = loop;
        }

        if (data.mediaNode != null) {
            node = data.mediaNode;
            data.mediaElem.loop = loop;
        }

        // Route through bus system: source -> pan -> gain -> bus
        node.connect(pan);
        pan.connect(gain);

        var busGain = getBusGainNode(busIndex);
        gain.connect(busGain);

        var sound:WebSound = {
            handle     : handle,
            source     : source,
            instance   : inst,
            bus        : busIndex, // Store bus assignment

            bufferNode : bufferNode,
            mediaNode  : data.mediaNode,
            mediaElem  : data.mediaElem,
            gainNode   : gain,
            panNode    : pan,

            state      : PLAYING,
            loop       : loop,
            pan        : 0,
            pitch      : 1,

            ignoreNextEnded : 0,

            timeResumeAppTime : Runtime.timestamp(),
            timeResume        : 0.0,
            timePause         : null
        };

        instances.set(handle, sound);

        // TODO handle paused flag, also why is there a paused flag?
        // when do you ever want to call play with paused as true?

        if (bufferNode != null) {
            bufferNode.start(0);
            bufferNode.onended = () -> {
                soundEnded(sound);
            };
        }

        if (data.mediaNode != null) {
            data.mediaElem.play();
            data.mediaElem.onended = () -> {
                soundEnded(sound);
            };
        }
    }

    public function play(source:AudioSource, volume:Float, paused:Bool, busIndex:Int = DEFAULT_BUS):AudioHandle {
        var data:WebAudioData = cast source.data;
        var handle = handleSeq;
        var inst = source.instance(handle);

        if (source.data.isStream) {
            data.mediaElem.play();
            data.mediaElem.volume = 1.0;
            playInstance(handle, source, inst, data, null, volume, false, busIndex);
        } else {
            playInstance(handle, source, inst, data, playBuffer(data), volume, false, busIndex);
        }

        handleSeq++;

        if (paused) {
            pause(handle);
        }

        return handle;
    }

    public function loop(source:AudioSource, volume:Float, paused:Bool, busIndex:Int = DEFAULT_BUS):AudioHandle {
        var data:WebAudioData = cast source.data;
        var handle = handleSeq;
        var inst = source.instance(handle);

        if (source.data.isStream) {
            data.mediaElem.play();
            data.mediaElem.volume = 1.0;
            playInstance(handle, source, inst, data, null, volume, true, busIndex);
        } else {
            playInstance(handle, source, inst, data, playBuffer(data), volume, true, busIndex);
        }

        handleSeq++;

        if (paused) {
            pause(handle);
        }

        return handle;
    }

    function stopBuffer(sound:WebSound) {
        sound.bufferNode.stop();
        sound.bufferNode.disconnect();
        sound.gainNode.disconnect();
        sound.panNode.disconnect();
        sound.bufferNode = null;
    }

    public function pause(handle:AudioHandle):Void {
        var sound = soundOf(handle);
        if (sound == null)
            return;
        if (sound.state != PLAYING)
            return;

        Log.debug('Audio / pause handle=$handle, ' + sound.source.data.id);

        var timePause = positionOf(handle);
        sound.timePause = timePause;
        sound.state = PAUSED;

        if (sound.bufferNode != null) {
            stopBuffer(sound);
        }
        else if (sound.mediaNode != null) {
            sound.mediaElem.pause();
        }
    }

    public function unPause(handle:AudioHandle):Void {
        var sound = soundOf(handle);
        if (sound == null)
            return;
        if (sound.state != PAUSED)
            return;

        Log.debug('Audio / unpause handle=$handle, ' + sound.source.data.id);

        sound.timeResume = sound.timePause != null ? sound.timePause : 0;
        sound.timeResumeAppTime = Runtime.timestamp();

        if (sound.mediaNode == null) {
            playBufferAgain(handle, sound, sound.timePause);
        }
        else {
            sound.mediaElem.play();
        }

        sound.state = PLAYING;
    }

    function soundEnded(sound:WebSound) {
        if (sound.ignoreNextEnded > 0) {
            sound.ignoreNextEnded--;
            return;
        }
        if (sound.state != PAUSED && (sound.state != PLAYING || positionOf(sound.handle) + 0.1 >= sound.source.getDuration())) {
            destroySound(sound);
        }
    }

    function destroySound(sound:WebSound) {
        if (sound.source != null && instances.exists(sound.handle) && positionOf(sound.handle) + 0.1 >= sound.source.getDuration()) {
            emitAudioEvent(END, sound.handle);
        }

        if (sound.bufferNode != null) {
            sound.bufferNode.stop();
            sound.bufferNode.disconnect();
            sound.gainNode.disconnect();
            sound.panNode.disconnect();
            sound.bufferNode = null;
        }

        if (sound.mediaNode != null) {
            sound.mediaElem.pause();
            sound.mediaElem.currentTime = 0;
            sound.mediaNode.disconnect();
            sound.mediaElem = null;
            sound.mediaNode = null;
        }

        if (sound.gainNode != null) {
            sound.gainNode.disconnect();
            sound.gainNode = null;
        }

        if (sound.panNode != null) {
            sound.panNode.disconnect();
            sound.panNode = null;
        }

        if (instances.exists(sound.handle)) {
            instances.remove(sound.handle);
            emitAudioEvent(DESTROYED, sound.handle);
        }
        sound = null;
    }

    public function stop(handle:AudioHandle):Void {
        var sound = soundOf(handle);
        if (sound == null) return;

        if (sound.state != STOPPED)
            Log.debug('Audio / stop handle=$handle' + (sound.source != null && sound.source.data != null ? ', '+sound.source.data.id : ''));

        destroySound(sound);

        sound.state = STOPPED;
    }

    public function volume(handle:AudioHandle, volume:Float):Void {
        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / volume=$volume handle=$handle, ' + sound.source.data.id);

        sound.gainNode.gain.value = volume;
    }

    public function pan(handle:AudioHandle, pan:Float):Void {
        var sound = soundOf(handle);
        if (sound == null)
            return;

        Log.debug('Audio / pan=$pan handle=$handle, ' + sound.source.data.id);

        sound.pan = pan;
        sound.panNode.setPosition(
            Math.cos((pan-1) * HALF_PI),
            0,
            Math.sin((pan+1) * HALF_PI)
        );
    }

    public function pitch(handle:AudioHandle, pitch:Float):Void {
        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / pitch=$pitch handle=$handle, ' + sound.source.data.id);

        if (sound.mediaNode == null) {
            var position = positionOf(handle);
            sound.pitch = pitch;
            if (sound.state == PLAYING) {
                // Adjust timeResumeAppTime so that it matches the new pitch
                sound.timeResumeAppTime = sound.timeResume + Runtime.timestamp() - (position / sound.pitch);
            }
        }

        if (sound.bufferNode != null) {
            sound.bufferNode.playbackRate.value = pitch;
        }
        else if (sound.mediaNode != null) {
            // Pitch not supported on streamed sounds
        }
    }

    public function position(handle:AudioHandle, time:Float):Void {
        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / position=$time handle=$handle, ' + sound.source.data.id);

        if (sound.state == PAUSED) {
            sound.timePause = time;
        }
        else {
            sound.timeResume = time;
            sound.timeResumeAppTime = Runtime.timestamp();

            if (sound.bufferNode != null) {
                sound.ignoreNextEnded++;
                ignoreEndedSoundsTick0.push(sound);
                stopBuffer(sound);
                playBufferAgain(handle, sound, time);
            }
            else {
                sound.mediaElem.currentTime = time;
            }
        }
    }

    public function volumeOf(handle:AudioHandle):Float {
        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        return sound.gainNode.gain.value;
    }

    public function panOf(handle:AudioHandle):Float {
        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        return sound.pan;
    }

    public function pitchOf(handle:AudioHandle):Float {
        var sound = soundOf(handle);
        if (sound == null) return 1.0;

        return sound.pitch;
    }

    public function positionOf(handle:AudioHandle):Float {
        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        if (sound.mediaElem == null) {
            switch sound.state {
                case INVALID | STOPPED:
                    return 0.0;
                case PLAYING | PAUSED:
                    var time = switch sound.state {
                        case PAUSED: sound.timePause;
                        case PLAYING: sound.timeResume + (Runtime.timestamp() - sound.timeResumeAppTime) * sound.pitch;
                        default: 0.0;
                    }
                    var duration = sound.source.getDuration();
                    if (duration > 0) {
                        if (sound.loop) {
                            time = time % duration;
                        }
                        else if (time > duration) {
                            time = duration;
                        }
                    }
                    return time;
            }
        }
        else {
            return sound.mediaElem.currentTime;
        }

        return 0.0;
    }

    public function stateOf(handle:AudioHandle):AudioState {
        var sound = soundOf(handle);
        if (sound == null) return INVALID;

        return sound.state;
    }

    public function loopOf(handle:AudioHandle):Bool {
        var sound = soundOf(handle);
        if (sound == null) return false;

        return sound.loop;
    }

    public function instanceOf(handle:AudioHandle):AudioInstance {
        var sound = soundOf(handle);
        if (sound == null) return null;

        return sound.instance;
    }

    public function suspend():Void {
        if (!active)
            return;
        if (suspended)
            return;

        suspended = true;
        active = false;
        context.suspend();
    }

    public function resume():Void {
        if (active)
            return;
        if (!suspended)
            return;

        suspended = false;
        active = true;
        context.resume();
    }

    // Additional utility methods for bus system
    public function getSoundBus(handle:AudioHandle):Int {
        var sound = soundOf(handle);
        return sound != null ? sound.bus : -1;
    }

    public function moveSoundToBus(handle:AudioHandle, newBusIndex:Int):Bool {
        var sound = soundOf(handle);
        if (sound == null) return false;

        var newBus = busses.get(newBusIndex);
        if (newBus == null) return false;

        // Reconnect to new bus
        sound.gainNode.disconnect();
        sound.gainNode.connect(newBus.gainNode);
        sound.bus = newBusIndex;

        Log.debug('Audio / Moved sound $handle to bus $newBusIndex');
        return true;
    }

    public function listBusses():Array<Int> {
        return [for (busIndex in busses.keys()) busIndex];
    }

    public function getBusName(busIndex:Int):String {
        var bus = busses.get(busIndex);
        return bus != null ? bus.name : "";
    }

    public function createBusFilter(
        uri:String,
        busIndex:Int,
        createFunc:(busIndex:Int, instanceId:Int)->Void,
        destroyFunc:(busIndex:Int, instanceId:Int)->Void
    ):Void {
        // Ensure bus exists before creating filter
        if (!busses.exists(busIndex)) {
            Log.debug('Audio / Bus $busIndex does not exist for filter, creating it automatically');
            createBus(busIndex);
        }

        loadWorkletModule('bus-worklet', uri, success -> {
            if (success) {
                if (attachWorkletToBus(busIndex, 'bus-worklet', {}, () -> {
                    Log.debug('Audio / Worklet attached to bus #$busIndex is now ready!');
                    createFunc(busIndex, busIndex);
                })) {
                }
                else {
                    Log.error('Audio / Failed to attach worklet to bus #$busIndex');
                }
            }
            else {
                Log.error('Audio / Failed to load create bus filter #$busIndex');
            }
        });

        // TODO destroy?
    }

    public function addBusFilterWorklet(busIndex:Int, filterId:Int, workletClass:Class<Any>, workletReady:()->Void):Void {
        // Ensure bus exists before adding filter worklet
        if (!busses.exists(busIndex)) {
            Log.debug('Audio / Bus $busIndex does not exist for filter worklet, creating it automatically');
            createBus(busIndex);
        }

        final bus = busses.get(busIndex);
        if (bus == null) {
            Log.error('Audio / Cannot add bus filter worklet: bus #$busIndex creation failed');
            return;
        }
        if (bus.workletNode == null) {
            Log.error('Audio / Cannot add bus filter worklet: bus #$busIndex has no worklet node');
            return;
        }

        final message = {
            type: "addBusFilterWorklet",
            bus: busIndex,
            filterId: filterId,
            workletClass: Type.getClassName(workletClass),
        };

        if (workletReady != null) {
            workletMessageCallbacks.push({
                type: "addBusFilterWorklet",
                bus: busIndex,
                filterId: filterId,
                callback: workletReady
            });
        }
        bus.workletNode.port.postMessage(message);

    }

    public function destroyBusFilterWorklet(busIndex:Int, filterId:Int):Void {
        final bus = busses.get(busIndex);
        if (bus == null) {
            Log.warning('Audio / Cannot destroy bus filter worklet: bus #$busIndex does not exist');
            return;
        }
        if (bus.workletNode == null) {
            Log.warning('Audio / Cannot destroy bus filter worklet: bus #$busIndex has no worklet node');
            return;
        }

        final message = {
            type: "destroyBusFilterWorklet",
            bus: busIndex,
            filterId: filterId
        };
        bus.workletNode.port.postMessage(message);
    }

    // Optional: Helper function to ensure a bus exists
    private function ensureBusExists(busIndex:Int):Bool {
        if (!busses.exists(busIndex)) {
            Log.debug('Audio / Auto-creating bus $busIndex');
            createBus(busIndex);
            return busses.exists(busIndex);
        }
        return true;
    }

/// Data API

    override function loadData(path:String, isStream:Bool, format:AudioFormat, async:Bool = false, ?callback:(data:AudioData)->Void):AudioData {
        if (path == null)
            throw 'path is null!';

        if (!active) {
            Log.error('Audio / WebAudio context unavailable');
            if (callback != null) {
                Immediate.push(() -> {
                    callback(null);
                });
            }
            return null;
        }

        if (isStream) {
            loadDataFromStream(path, format, callback);
            return null;
        }

        loadDataFromSound(path, format, callback);
        return null;
    }

    public function dataFromBytes(id:String, bytes:Uint8Array, ?format:AudioFormat, ?callback:(data:AudioData)->Void):Void {
        if (!active) {
            if (callback != null) {
                Immediate.push(() -> {
                    callback(null);
                });
            }
            return;
        }

        if (id == null)
            throw 'id is null!';
        if (bytes == null)
            throw 'bytes is null!';

        context.decodeAudioData(bytes.buffer, function(buffer:js.html.audio.AudioBuffer) {
            var data = new WebAudioData(app, buffer, null, null, {
                id         : id,
                isStream   : false,
                format     : format,
                samples    : null,
                length     : buffer.length,
                channels   : buffer.numberOfChannels,
                duration   : buffer.duration,
                rate       : Std.int(buffer.sampleRate)
            });

            if (callback != null) {
                Immediate.push(() -> {
                    callback(data);
                });
            }
        }, function() {
            Log.error('Audio / failed to decode audio for `$id`');
            if (callback != null) {
                Immediate.push(() -> {
                    callback(null);
                });
            }
        });
    }

    function handleSourceDestroyed(source:AudioSource):Void {
        //
    }

    function handleInstanceDestroyed(handle:AudioHandle):Void {
        stop(handle);
    }

/// Internal

    function loadDataFromSound(path:String, format:AudioFormat, ?callback:(data:AudioData)->Void):Void {
        app.io.loadData(path, true, function(bytes) {
            if (bytes != null) {
                dataFromBytes(path, bytes, format, callback);
            }
            else {
                if (callback != null) {
                    Immediate.push(() -> {
                        callback(null);
                    });
                }
            }
        });
    }

    function loadDataFromStream(path:String, format:AudioFormat, ?callback:(data:AudioData)->Void):Void {
        // Create audio element
        var element = new js.html.Audio(path);
        element.autoplay = false;
        element.controls = false;
        element.preload = 'auto';

        element.onerror = function(err) {
            var error = switch(element.error.code) {
                case 1: 'MEDIA_ERR_ABORTED';
                case 2: 'MEDIA_ERR_NETWORK';
                case 3: 'MEDIA_ERR_DECODE';
                case 4: 'MEDIA_ERR_SRC_NOT_SUPPORTED';
                case 5: 'MEDIA_ERR_ENCRYPTED';
                case _: 'unknown error';
            }

            Log.error('Audio / failed to load `$path` as stream : `$error`');
            if (callback != null) {
                Immediate.push(() -> {
                    callback(null);
                });
            }
        };

        element.onloadedmetadata = function(_) {
            var node = context.createMediaElementSource(element);

            // Web Audio works with 32 bit IEEE float samples
            var bytesPerSample = 2; // this is for 16, though
            var rate = Std.int(context.sampleRate);
            var channels = node.channelCount;

            var sampleFrames = rate * channels * bytesPerSample;
            var length = Std.int(element.duration * sampleFrames);

            var data = new WebAudioData(app, null, node, element, {
                id         : path,
                isStream   : true,
                format     : format,
                samples    : null,
                length     : length,
                channels   : channels,
                rate       : rate,
                duration   : element.duration
            });

            if (callback != null) {
                Immediate.push(() -> {
                    callback(data);
                });
            }
        };
    }
}

private class WebAudioData extends AudioData {

    public var buffer: js.html.audio.AudioBuffer;
    public var mediaNode: js.html.audio.MediaElementAudioSourceNode;
    public var mediaElem: js.html.Audio;

    inline public function new(
        app:Clay,
        ?buffer:js.html.audio.AudioBuffer,
        ?mediaNode:js.html.audio.MediaElementAudioSourceNode,
        ?mediaElem:js.html.Audio,
        options:AudioDataOptions
    ) {
        this.buffer = buffer;
        this.mediaNode = mediaNode;
        this.mediaElem = mediaElem;

        super(app, options);
    }

    override public function destroy() {
        buffer = null;
        mediaNode = null;
        mediaElem = null;

        super.destroy();
    }
}

#end