package clay.web;

#if js

import clay.buffers.Uint8Array;
import clay.buffers.Float32Array;
import clay.audio.AudioSource;
import clay.audio.AudioInstance;
import clay.audio.AudioHandle;
import clay.audio.AudioData;
import clay.audio.AudioState;
import clay.audio.AudioFormat;

private typedef WebSound = {
    source: AudioSource,
    handle: AudioHandle,
    instance: AudioInstance,

    bufferNode: js.html.audio.AudioBufferSourceNode,
    mediaNode: js.html.audio.MediaElementAudioSourceNode,
    mediaElem: js.html.Audio,

    gainNode: js.html.audio.GainNode,
    panNode: js.html.audio.PannerNode,

    state: AudioState,
    loop: Bool,
    pan: Float,
    timeResume: Float,
    timeResumeAppTime: Float,
    ?timePause: Float,
}

@:allow(clay.audio.AudioInstance)
@:allow(clay.audio.AudioSource)
class WebAudio extends clay.base.BaseAudio {

    static inline var HALF_PI:Float = 1.5707;

    var suspended:Bool = false;

    var handleSeq:Int = 0;

    var instances:Map<AudioHandle, WebSound>;
    var buffers:Map<AudioSource, js.html.audio.AudioBuffer>;

    public var context(default, null):js.html.audio.AudioContext;

    public var active(default, null):Bool = false;

    function new(app:Clay) {

        super(app);

        instances = new Map();

    }

    override function init() {

        initWebAudio();

    }

    function initWebAudio() {

        try {
            context = new js.html.audio.AudioContext();
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

        context.close();

    }

    inline function soundOf(handle:AudioHandle):WebSound {

        return instances.get(handle);

    }

    function playBuffer(data:WebAudioData):js.html.audio.AudioBufferSourceNode {

        var node = context.createBufferSource();
        node.buffer = data.buffer;

        return node;

    }

    function playBufferAgain(handle:AudioHandle, sound:WebSound, startTime:Float) {

        sound.bufferNode = playBuffer(cast sound.source.data);
        sound.bufferNode.connect(sound.panNode);
        sound.bufferNode.loop = sound.loop;
        sound.panNode.connect(sound.gainNode);
        sound.gainNode.connect(context.destination);
        sound.bufferNode.start(0, startTime);
        sound.bufferNode.onended = destroySound.bind(sound);

    }

    function playInstance(
        handle:AudioHandle,
        source:AudioSource,
        inst:AudioInstance,
        data:WebAudioData,
        bufferNode:js.html.audio.AudioBufferSourceNode,
        volume:Float,
        loop:Bool
    ) {

        var gain = context.createGain();
        var pan = context.createPanner();
        var node: js.html.audio.AudioNode = null;
        var panVal = 0;

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

        // source -> pan -> gain -> output
        node.connect(pan);
        pan.connect(gain);
        gain.connect(context.destination);

        var sound:WebSound = {
            handle     : handle,
            source     : source,
            instance   : inst,

            bufferNode : bufferNode,
            mediaNode  : data.mediaNode,
            mediaElem  : data.mediaElem,
            gainNode   : gain,
            panNode    : pan,

            state      : PLAYING,
            loop       : loop,
            pan        : 0,

            timeResumeAppTime : app.timestamp,
            timeResume        : 0.0,
            timePause         : null
        };

        instances.set(handle, sound);

        // TODO handle paused flag, also why is there a paused flag? 
        // when do you ever want to call play with paused as true?

        if (bufferNode != null) {
            bufferNode.start(0);
            bufferNode.onended = destroySound.bind(sound);
        }

        if (data.mediaNode != null) {

            data.mediaElem.play();

            // TODO looping audio element ended event
            data.mediaNode.addEventListener('ended', function() {
                emitAudioEvent(END, handle);
                sound.state = STOPPED;
            });

        } //media node

    }

    public function play(source:AudioSource, volume:Float, paused:Bool):AudioHandle {

        var data:WebAudioData = cast source.data;
        var handle = handleSeq;
        var inst = source.instance(handle);

        if (source.data.isStream) {
            data.mediaElem.play();
            data.mediaElem.volume = 1.0;
            playInstance(handle, source, inst, data, null, volume, false);
        } else {
            playInstance(handle, source, inst, data, playBuffer(data), volume, false);
        }

        handleSeq++;

        return handle;

    }

    public function loop(source:AudioSource, volume:Float, paused:Bool):AudioHandle {

        var data:WebAudioData = cast source.data;
        var handle = handleSeq;
        var inst = source.instance(handle);

        if (source.data.isStream) {
            data.mediaElem.play();
            data.mediaElem.volume = 1.0;
            playInstance(handle, source, inst, data, null, volume, true);
        } else {
            playInstance(handle, source, inst, data, playBuffer(data), volume, true);
        }

        handleSeq++;

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

        Log.debug('Audio / pause handle=$handle, ' + sound.source.data.id);

        var timePause = sound.timeResume + app.timestamp - sound.timeResumeAppTime;
        var duration = sound.source.getDuration();
        if (duration > 0) {
            if (sound.loop) {
                timePause = timePause % duration;
            }
            else if (timePause > duration) {
                timePause = duration;
            }
        }
        sound.timePause = timePause;
        sound.state = PAUSED;

        if (sound.bufferNode != null) {
            stopBuffer(sound);
        }
        else if(sound.mediaNode != null) {
            sound.mediaElem.pause();
        }

    }

    public function unPause(handle:AudioHandle):Void {

        var sound = soundOf(handle);
        if (sound == null) return;
        if (sound.state != PAUSED) return;

        Log.debug('Audio / unpause handle=$handle, ' + sound.source.data.id);

        sound.timeResume = sound.timePause != null ? sound.timePause : 0;
        sound.timeResumeAppTime = app.timestamp;

        if (sound.mediaNode == null) {
            playBufferAgain(handle, sound, sound.timePause);
        }
        else {
            sound.mediaElem.play();
        }

        sound.state = PLAYING;

    }

    function destroySound(sound:WebSound) {

        if (sound.bufferNode != null) {
            sound.bufferNode.stop();
            sound.bufferNode.disconnect();
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

        instances.remove(sound.handle);
        sound = null;

    }

    public function stop(handle:AudioHandle):Void {

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / stop handle=$handle, ' + sound.source.data.id);

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

        if (sound.bufferNode != null) {
            sound.bufferNode.playbackRate.value = pitch;
        }
        else if (sound.mediaNode != null) {
            sound.mediaElem.playbackRate = pitch;
        }

    }

    public function position(handle:AudioHandle, time:Float):Void {

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / position=$time handle=$handle, ' + sound.source.data.id);

        if (sound.bufferNode != null) {
            stopBuffer(sound);
            playBufferAgain(handle, sound, time);
        }
        else {
            sound.mediaElem.currentTime = time;
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
        if (sound == null) return 0.0;

        var result = 1.0;

        if (sound.bufferNode != null) {
            result = sound.bufferNode.playbackRate.value;
        }
        else if (sound.mediaNode != null) {
            result = sound.mediaElem.playbackRate;
        }

        return result;

    }

    public function positionOf(handle:AudioHandle):Float {

        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        if (sound.bufferNode != null) {
            switch sound.state {
                case INVALID | STOPPED:
                    return 0.0;
                case PLAYING | PAUSED:
                    var time = switch sound.state {
                        case PAUSED: sound.timePause;
                        case PLAYING: sound.timeResume + (app.timestamp - sound.timeResumeAppTime);
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

        if (suspended)
            return;

        suspended = true;
        context.suspend();

    }

    public function resume():Void {

        if (!suspended)
            return;

        suspended = false;

        context.resume();

    }

/// Data API

    override function loadData(path:String, isStream:Bool, format:AudioFormat, ?callback:(data:AudioData)->Void):AudioData {

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

        context.decodeAudioData(bytes.buffer, function(buffer:js.html.audio.AudioBuffer) {

            var data = new WebAudioData(app, buffer, null, null, {
                id         : id,
                isStream   : false,
                format     : format,
                samples    : null,
                length     : buffer.length,
                channels   : buffer.numberOfChannels,
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

        //

    }

/// Internal

    function loadDataFromSound(path:String, format:AudioFormat, ?callback:(data:AudioData)->Void):Void {

        app.io.loadData(path, true, function(bytes) {

            dataFromBytes(path, bytes, format, callback);

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
                rate       : rate
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