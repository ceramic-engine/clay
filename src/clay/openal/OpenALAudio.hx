package clay.openal;

import clay.Types;
import clay.audio.AudioErrorReason;
import clay.audio.AudioHandle;
import clay.audio.AudioInstance;
import clay.audio.AudioSource;
import clay.audio.AudioState;
import clay.openal.AL.Context;
import clay.openal.AL.Device;
import clay.openal.AL;
import clay.openal.ALSound;
import clay.openal.ALStream;

@:allow(clay.openal.OpenALAudio)
class OpenALSound {

    var source:AudioSource = null;

    var firstHandle:AudioHandle = -1;

    var handle:AudioHandle = -1;
    
    var timeResume:Float = -1;

    var timeResumeAppTime:Float = -1;

    var timePause:Float = -1;

    var pitch:Float = 1.0;

    var loop:Bool = false;

    var volume:Float = 0.5;

    private function new() {
        //
    }

}


@:allow(clay.audio.AudioSource)
@:allow(clay.audio.AudioInstance)
@:allow(clay.openal.ALSound)
@:allow(clay.openal.ALStream)
class OpenALAudio extends clay.native.NativeAudio {

    static inline var HALF_PI:Float = 1.5707;

    public var device:Device;
    public var context:Context;

    var suspended:Bool = false;

    var handleSeq:Int = 1;
    var instances:IntMap<ALSound>;
    var instancesData:IntMap<OpenALSound>;

    #if ceramic
    var instancesKeys:Array<Int>;
    var instancesDataKeys:Array<Int>;
    #end

    /** A map of audio source to AL buffer handles */
    var buffers:Map<String, ALuint>;

    public var active(default, null):Bool = false;

    override public function new(app:Clay) {

        super(app);

        #if ceramic
        instances = new IntMap(16, 0.5, true);
        instancesKeys = [];
        instancesData = new IntMap(16, 0.5, true);
        instancesDataKeys = [];
        #else
        instances = new IntMap();
        instancesData = new IntMap();
        #end
        buffers = new Map();

    }

    override function init():Void {

        initAL();

    }

    override function tick(delta):Void {

        if (!active)
            return;

        #if ceramic
        // Iterate over a copy of keys because original keys array
        // will change if we add/destroy a sound instance during iteration.
        // This code is still better than regular haxe.ds.IntMap.keys()
        // because it doesn't need any allocation as we always
        // reuse the same array for the copy.
        var iterableKeys = instances.iterableKeys;
        var len = iterableKeys.length;
        for (i in 0...len) {
            instancesKeys[i] = iterableKeys[i];
        }
        for (i in 0...len) {
            var handle:Int = instancesKeys[i];
            tickAudioHandle(delta, handle);
        }

        iterableKeys = instancesData.iterableKeys;
        len = iterableKeys.length;
        for (i in 0...len) {
            instancesDataKeys[i] = iterableKeys[i];
        }
        for (i in 0...len) {
            var handle:Int = instancesDataKeys[i];
            tickInstanceData(delta, handle);
        }
        #else
        // Ceramic not available, this will create an array on the fly
        for (handle in instances.keys()) {
            tickAudioHandle(delta, handle);
        }
        for (handle in instancesData.keys()) {
            tickInstanceData(delta, handle);
        }
        #end

    }

    #if !clay_debug inline #end function tickAudioHandle(delta:Float, handle:AudioHandle):Void {

        var sound:ALSound = instances.get(handle);
        if (sound != null) {
            sound.tick(delta);

            var didEmitEnd = false;

            var previousTime = sound.currentTime;
            sound.currentTime = positionOf(handle);

            if (sound.looping && !sound.source.data.isStream) {
                if (previousTime > sound.currentTime && previousTime + 0.1 >= sound.source.getDuration()) {
                    emitAudioEvent(END, handle);
                    didEmitEnd = true;
                }
            }

            if (sound.instance.hasEnded()) {

                if (!didEmitEnd && !sound.isStreamLoopSound)
                    emitAudioEvent(END, handle);

                if (!sound.instance.destroyed) {
                    sound.instance.destroy();
                }
            }
        }

    }

    #if !clay_debug inline #end function tickInstanceData(delta:Float, handle:AudioHandle):Void {

        var instanceData = instancesData.get(handle);
        if (instanceData != null) {
            if (instanceData.loop) {
                var state = stateOf(instanceData.handle);
                switch state {
                    default:
                    case PLAYING:
                        var time = switch state {
                            case PLAYING: instanceData.timeResume + (app.timestamp - instanceData.timeResumeAppTime) * instanceData.pitch;
                            default: 0.0;
                        }
                        var duration = instanceData.source.getDuration();
                        if (duration > 0) {
                            var dt = Math.min(delta, 1.0 / 30);
                            if (time > duration - dt) {
                                emitAudioEvent(END, handle);
                                time = 0.0;
                                _stop(instanceData.handle);
                                _loop(instanceData.source, instanceData.volume, false, instanceData);
                            }
                        }
                }
            }
        }

    }

    function handleSourceDestroyed(source:AudioSource):Void {

        var buffer = buffers.get(source.sourceId);
        if (buffer != null) {
            Log.debug('Audio / destroying buffer ' + buffer);
            AL.deleteBuffer(buffer);
            Log.debug('Audio / delete buffer / ${ALError.desc(AL.getError())}');
        }

        var removed = buffers.remove(source.sourceId);
        Log.debug('Audio / source being destroyed / ${source.data.id} / buffer $buffer / removed? $removed');

        emitAudioEvent(DESTROYED_SOURCE, null);

    }

    function handleInstanceDestroyed(handle:AudioHandle):Void {

        Log.debug('Audio / instance was destroyed: $handle');

        var sound = instances.get(handle);

        if (sound != null) {
            Log.debug('Audio / sound: ' + sound.source.data.id);
            sound.destroy();
            sound = null;
        }

        instances.remove(handle);

        var instanceData = instancesData.get(handle);
        if (instanceData != null) {
            if (!instanceData.loop || instanceData.firstHandle != handle) {
                instancesData.remove(handle);
            }
        }

        emitAudioEvent(DESTROYED, handle);

    }

    override function shutdown() {

        if (!active) return;

        #if ceramic
        for (i in 0...instances.values.length) {
            var sound = instances.values[i];
            if (sound == null)
                continue;
        #else
        for (sound in instances) {
        #end
            #if ios
            try {
                // Surrounding this call with try/catch
                // because on iOS, when leaving app,
                // it seems to make the app crash
            #end
                sound.instance.destroy();
            #if ios
            }
            catch (e:Dynamic) {
                Log.error('Failed to destroy sound instance: ' + e);
            }
            #end
        }

        for (buffer in buffers) {
            AL.deleteBuffer(buffer);
        }

        ALC.makeContextCurrent(cast null);
        Log.debug('Audio / invalidate context / ${ ALCError.desc(ALC.getError(device)) }');

        ALC.destroyContext(context);
        Log.debug('Audio / destroyed context / ${ ALCError.desc(ALC.getError(device)) }');

        ALC.closeDevice(device);
        Log.debug('Audio / closed device / ${ ALCError.desc(ALC.getError(device)) }');

        buffers = null;
        instances = null;
        device = null;
        context = null;

    }

/// Internal

    function initAL() {

        Log.debug('Audio / init');
        device = ALC.openDevice();

        if (device == null) {
            Log.error('Audio / failed / didn\'t create device!');
            return;
        }

        Log.debug('Audio / created device / ${device} / ${ ALCError.desc(ALC.getError(device)) }');

        context = ALC.createContext(device, null);
        Log.debug('Audio / created context / ${context} / ${ ALCError.desc(ALC.getError(device)) }');

        ALC.makeContextCurrent(context);
        Log.debug('Audio / set current / ${ ALCError.desc(ALC.getError(device)) }');

        active = true;

    }

    override function ready() {

        Log.debug('Audio / ready');

    }

/// Public API

    public function suspend() {

        if (!active) return;
        if (suspended) return;

        suspended = true;
        active = false;

        Log.debug('Audio / suspend AL ${ALError.desc(AL.getError())}');
        Log.debug('Audio / suspend ALC ${ALCError.desc(ALC.getError(device))}');

        #if android
        Log.debug('Audio / android: alc suspend');
        ALC.androidSuspend();
        #end

        ALC.suspendContext(context);
        ALC.makeContextCurrent(cast null);

    }

    public function resume() {

        if (active) return;
        if (!suspended) return;

        suspended = false;
        active = true;

        Log.debug('Audio / resuming context');

        #if android
        Log.debug('Audio / android: alc resume');
        ALC.androidResume();
        #end

        ALC.makeContextCurrent(context);
        ALC.processContext(context);

        Log.debug('Audio / resume AL ${ALError.desc(AL.getError())}');
        Log.debug('Audio / resume ALC ${ALCError.desc(ALC.getError(device))}');

    }

    inline function soundOf(handle:AudioHandle):ALSound {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        return handle == null || (handle:Int) == -1 ? null : instances.get(handle);

    }

    /** Play an instance of the given audio source, returning a disposable handle */
    public function play(source:AudioSource, volume:Float, paused:Bool):AudioHandle {

        if (source == null)
            throw 'source is null!';
        if (source.data == null)
            throw 'source.data is null!';

        var handle = handleSeq;
        var inst = source.instance(handle);

        Log.debug('Audio / playing source ${source.data.id} as stream: ${source.data.isStream}');

        var sound = switch(source.data.isStream) {
            case false: new ALSound(this, source, inst);
            case true : new ALStream(this, source, inst);
        }

        sound.init();
        instances.set(handle, sound);

        if (source.data.isStream) {
            var instanceData = new OpenALSound();
            instancesData.set(handle, instanceData);
            instanceData.firstHandle = handle;
            instanceData.handle = handle;
            instanceData.source = source;
            instanceData.timeResume = 0.0;
            instanceData.timeResumeAppTime = app.timestamp;
            instanceData.timePause = -1;
            instanceData.pitch = 1.0;
            instanceData.loop = false;
            instanceData.volume = volume;
        }

        #if clay_openal_no_linear_volume
        AL.sourcef(sound.alsource, AL.GAIN, volume);
        #else
        AL.sourcef(sound.alsource, AL.GAIN, volume < 1.0 ? volume * volume : volume * 1.0);
        #end

        if (!paused) {
            AL.sourcePlay(sound.alsource);
        }

        Log.debug('Audio / play ${source.data.id}, handle=$handle');
        ensureNoError(PLAY);

        handleSeq++;

        return handle;

    }

    /** Play and loop a sound instance indefinitely. Use stop to end it.
        Returns a disposable handle */
    public function loop(source:AudioSource, volume:Float, paused:Bool):AudioHandle {

        return _loop(source, volume, paused, null);

    }

    function _loop(source:AudioSource, volume:Float, paused:Bool, instanceData:OpenALSound):AudioHandle {

        var handle = play(source, volume, paused);
        var sound = soundOf(handle);

        if (!sound.source.data.isStream) {
            sound.looping = true;
            AL.sourcei(sound.alsource, AL.LOOPING, AL.TRUE);
        }

        if (sound.source.data.isStream) {
            // We loop at instanceData level, not at ALSound level
            sound.isStreamLoopSound = true;
            if (instanceData == null) {
                instanceData = new OpenALSound();
                instanceData.firstHandle = handle;
            }
            instancesData.set(handle, instanceData);
            instanceData.handle = handle;
            instanceData.source = sound.source;
            instanceData.timeResume = 0.0;
            instanceData.timeResumeAppTime = app.timestamp;
            instanceData.timePause = -1;
            instanceData.pitch = 1.0;
            instanceData.loop = true;
            instanceData.volume = volume;
        }

        Log.debug('Audio / loop ${source.data.id}, handle=$handle');

        ensureNoError(LOOP);

        return handle;

    }

    public function pause(handle:AudioHandle):Void {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / pause handle=$handle, ' + sound.source.data.id);

        if (instanceData != null) {
            var timePause = positionOf(instanceData.firstHandle);
            instanceData.timePause = timePause;
        }

        AL.sourcePause(sound.alsource);

        ensureNoError(PAUSE);

    }

    public function unPause(handle:AudioHandle):Void {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / unpause handle=$handle, ' + sound.source.data.id);

        if (instanceData != null) {
            instanceData.timeResume = instanceData.timePause > 0 ? instanceData.timePause : 0;
            instanceData.timeResumeAppTime = app.timestamp;
            instanceData.timePause = -1;
        }

        AL.sourcePlay(sound.alsource);

        ensureNoError(UNPAUSE);

    }

    public function stop(handle:AudioHandle):Void {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        if (instanceData != null) {
            instancesData.remove(instanceData.firstHandle);
        }

        _stop(handle);

    }

    function _stop(handle:AudioHandle):Void {

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / stop handle=$handle, ' + sound.source.data.id);

        AL.sourceStop(sound.alsource);

        ensureNoError(STOP);

    }

    /** Set the volume of a sound instance */
    public function volume(handle:AudioHandle, volume:Float):Void {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / volume=$volume handle=$handle, ' + sound.source.data.id);

        if (instanceData != null) {
            instanceData.volume = volume;
        }

        #if clay_openal_no_linear_volume
        AL.sourcef(sound.alsource, AL.GAIN, volume);
        #else
        AL.sourcef(sound.alsource, AL.GAIN, volume < 1.0 ? volume * volume : volume * 1.0);
        #end

    }

    /**
     * Set the pan of a sound instance.
     * Note: OpenAL is only capable of audio panning MONO audio sources so far.
     */
    public function pan(handle:AudioHandle, pan:Float):Void {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / pan=$pan handle=$handle, ' + sound.source.data.id);

        sound.pan = pan;

        AL.source3f(sound.alsource, AL.POSITION, Math.cos((pan - 1) * (HALF_PI)), 0, Math.sin((pan + 1) * (HALF_PI)));

    }

    /** Set the pitch of a sound instance */
    public function pitch(handle:AudioHandle, pitch:Float):Void {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / pitch=$pitch handle=$handle, ' + sound.source.data.id);

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null) {
            var position = positionOf(instanceData.firstHandle);
            instanceData.pitch = pitch;
            instanceData.timeResumeAppTime = instanceData.timeResume + app.timestamp - (position / pitch);
        }

        AL.sourcef(sound.alsource, AL.PITCH, pitch);

    }

    /** Set the position of a sound instance */
    public function position(handle:AudioHandle, time:Float):Void {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / position=$time handle=$handle, ' + sound.source.data.id);
        
        if (instanceData != null) {
            var state = stateOf(handle);
            if (state == PAUSED) {
                instanceData.timePause = time;
            }
            else {
                instanceData.timeResume = time;
                instanceData.timeResumeAppTime = app.timestamp;
            }
        }

        sound.currentTime = time;
        sound.setPosition(time);

    }

    /** Get the volume of a sound instance */
    public function volumeOf(handle:AudioHandle):Float {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        #if clay_openal_no_linear_volume
        return AL.getSourcef(sound.alsource, AL.GAIN);
        #else
        var volume = AL.getSourcef(sound.alsource, AL.GAIN);
        return volume < 1.0 ? Math.sqrt(volume) : volume * 1.0;
        #end

    }

    /** Get the pan of a sound instance */
    public function panOf(handle:AudioHandle):Float {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        return sound.pan;

    }

    /** Get the pitch of a sound instance */
    public function pitchOf(handle:AudioHandle):Float {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return 1.0;

        return AL.getSourcef(sound.alsource, AL.PITCH);

    }

    /** Get the position of a sound instance */
    public function positionOf(handle:AudioHandle):Float {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        if (instanceData != null) {
            var state = stateOf(handle);
            switch state {
                case INVALID | STOPPED:
                    return 0.0;
                case PLAYING | PAUSED:
                    var time = switch state {
                        case PAUSED: instanceData.timePause;
                        case PLAYING: instanceData.timeResume + (app.timestamp - instanceData.timeResumeAppTime) * instanceData.pitch;
                        default: 0.0;
                    }
                    var duration = instanceData.source.getDuration();
                    if (duration > 0) {
                        if (instanceData.loop) {
                            time = time % duration;
                        }
                        else if (time > duration) {
                            time = duration;
                        }
                        return time;
                    }
            }
            return 0.0;
        }

        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        return sound.getPosition();

    }

    /** Get the playback state of a handle */
    public function stateOf(handle:AudioHandle):AudioState {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null || !app.audio.active) return AudioState.INVALID;

        return switch(AL.getSourcei(sound.alsource, AL.SOURCE_STATE)) {
            case AL.PLAYING:                AudioState.PLAYING;
            case AL.PAUSED:                 AudioState.PAUSED;
            case AL.STOPPED, AL.INITIAL:    AudioState.STOPPED;
            case _:                         AudioState.INVALID;
        }

    }

    /** Get the looping state of a handle */
    public function loopOf(handle:AudioHandle):Bool {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return false;

        return sound.looping;

    }

    /** Get the audio instance of a handle, use with caution. */
    public function instanceOf(handle:AudioHandle):AudioInstance {

        var instanceData = handle != null ? instancesData.get(handle) : null;
        if (instanceData != null)
            handle = instanceData.handle;

        var sound = soundOf(handle);
        if (sound == null) return null;

        return sound.instance;

    }

    #if clay_no_openal_error_throw
    static var _numPrintedErrors:Int = 0;
    #end

    inline function ensureNoError(reason:AudioErrorReason, ?pos:haxe.PosInfos) {

        var err = AL.getError();

        if (err != AL.NO_ERROR && !Clay.app.shuttingDown) {
            if (err != -1) {
                var s = 'Audio / $err / $reason: failed with ' + ALError.desc(err);
                #if clay_no_openal_error_throw
                if (_numPrintedErrors++ < 32) {
                    haxe.Log.trace(s, pos);
                }
                #else
                haxe.Log.trace(s, pos);
                throw s;
                #end
            }
            else {
                var s = 'Audio / $reason / not played, too many concurrent sounds?';
                haxe.Log.trace(s, pos);
                Log.debug(s);
            }
        } else {
            Log.debug('Audio / $reason / no error');
        }
    }

}