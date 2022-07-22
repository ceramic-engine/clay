package clay.soloud;

import clay.Types;
import clay.audio.AudioData;
import clay.audio.AudioData;
import clay.audio.AudioFormat;
import clay.audio.AudioFormat;
import clay.audio.AudioHandle;
import clay.audio.AudioInstance;
import clay.audio.AudioSource;
import clay.audio.AudioState;
import clay.buffers.Uint8Array;
import haxe.io.Path;
import soloud.Soloud;
import soloud.Wav;
import soloud.WavStream;
import sys.FileSystem;
import sys.io.File;

using StringTools;

@:allow(clay.audio.AudioInstance)
@:allow(clay.audio.AudioSource)
class SoloudAudio extends clay.base.BaseAudio {

    // This is mostly used to have similar volumes
    // between web and native implementations
    public static var VOLUME_FACTOR:Float = 1.75;

    @:unreflective var soloud:Soloud;

    var suspended:Bool = false;

    var handleSeq:Int = 0;

    public var active(default, null):Bool = false;

    var instances:IntMap<SoloudSound> = new IntMap();

    var handles:Array<Int> = [];

    var suspendedHandles:Array<Int> = [];

    override public function new(app:Clay) {

        super(app);

    }

    override function init() {

        super.init();

        soloud = Soloud.create();
        var result = soloud.init();
        if (result == 0)
            active = true;
        else {
            var error:SoloudErrors = result;
            Log.error('Failed to init audio: ' + error);
        }

    }

    override function shutdown() {

        soloud.deinit();
        soloud.destroy();
        soloud = untyped __cpp__('NULL');

        super.shutdown();

    }

    override function tick(delta:Float) {

        for (i in 0...handles.length) {
            #if cpp
            var handle = cpp.NativeArray.unsafeGet(handles, i);
            #else
            var handle = handles[i];
            #end
            var sound = soundOf(handle);
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

    }

    function handleSourceDestroyed(source:AudioSource):Void {

        //

    }

    function handleInstanceDestroyed(handle:AudioHandle):Void {

        stop(handle);

    }

    public function instanceOf(handle:AudioHandle):AudioInstance {

        var sound = soundOf(handle);
        if (sound == null) return null;

        return sound.audioInstance;

    }

    inline function soundOf(handle:AudioHandle):SoloudSound {

        return instances.get(handle);

    }

    public function play(source:AudioSource, volume:Float, paused:Bool):AudioHandle {

        return _play(source, volume, paused, false);

    }

    public function loop(source:AudioSource, volume:Float, paused:Bool):AudioHandle {

        return _play(source, volume, paused, true);

    }

    function _play(source:AudioSource, volume:Float, paused:Bool, loop:Bool):AudioHandle {

        var data:SoloudAudioData = cast source.data;
        var handle = handleSeq;

        var inst = source.instance(handle);
        var soloudHandle:Int = -1;

        if (data.isStream) {
            soloudHandle = soloud.play(data.wavStream, volume * VOLUME_FACTOR, 0.0, paused);
        } else {
            soloudHandle = soloud.play(data.wav, volume * VOLUME_FACTOR, 0.0, paused);
        }

        if (loop)
            soloud.setLooping(soloudHandle, true);

        var sound = SoloudSound.get();
        sound.source = source;
        sound.soloudHandle = soloudHandle;
        sound.audioInstance = inst;
        sound.handle = handle;
        sound.state = PLAYING;
        sound.loop = loop;
        sound.volume = volume;
        sound.timeResume = 0.0;
        sound.timeResumeAppTime = app.timestamp;
        sound.timePause = -1;
        instances.set(handle, sound);
        handles.push(handle);

        handleSeq++;

        if (paused)
            pause(handle);

        return handle;

    }

    public function stop(handle:AudioHandle):Void {

        var sound = soundOf(handle);
        if (sound == null) return;

        if (sound.state != STOPPED)
            Log.debug('Audio / stop handle=$handle' + (sound.source != null && sound.source.data != null ? ', '+sound.source.data.id : ''));

        soloud.stop(sound.soloudHandle);

        destroySound(sound);

        sound.state = STOPPED;

    }

    function destroySound(sound:SoloudSound) {

        if (sound.source != null && instances.exists(sound.handle) && positionOf(sound.handle) + 0.1 >= sound.source.getDuration()) {
            emitAudioEvent(END, sound.handle);
        }

        if (instances.exists(sound.handle)) {
            instances.remove(sound.handle);
            handles.remove(sound.handle);
            suspendedHandles.remove(sound.handle);
            emitAudioEvent(DESTROYED, sound.handle);
        }

        sound.recycle();
        sound = null;

    }

    public function suspend():Void {

        if (!active)
            return;
        if (suspended)
            return;

        suspended = true;
        active = false;

        for (i in 0...handles.length) {
            #if cpp
            var handle = cpp.NativeArray.unsafeGet(handles, i);
            #else
            var handle = handles[i];
            #end
            var sound = soundOf(handle);
            switch sound.state {
                default:
                case PLAYING:
                    pause(handle);
                    suspendedHandles.push(handle);
            }
        }

    }

    public function resume():Void {

        if (active)
            return;
        if (!suspended)
            return;

        suspended = false;
        active = true;

        while (suspendedHandles.length > 0) {
            var handle = suspendedHandles.pop();
            unPause(handle);
        }

    }

    public function pan(handle:AudioHandle, pan:Float):Void {

        var sound = soundOf(handle);
        if (sound == null)
            return;

        Log.debug('Audio / pan=$pan handle=$handle, ' + sound.source.data.id);

        sound.pan = pan;
        soloud.setPan(sound.soloudHandle, pan);

    }

    public function volume(handle:AudioHandle, volume:Float):Void {

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / volume=$volume handle=$handle, ' + sound.source.data.id);

        sound.volume = volume;
        soloud.setVolume(sound.soloudHandle, volume * VOLUME_FACTOR);

    }

    public function pitch(handle:AudioHandle, pitch:Float):Void {

        var sound = soundOf(handle);
        if (sound == null) return;

        Log.debug('Audio / pitch=$pitch handle=$handle, ' + sound.source.data.id);

        sound.pitch = pitch;

        var position = positionOf(handle);
        if (sound.state == PLAYING) {
            // Adjust timeResumeAppTime so that it matches the new pitch
            sound.timeResumeAppTime = sound.timeResume + app.timestamp - (position / sound.pitch);
        }

        soloud.setRelativePlaySpeed(sound.soloudHandle, pitch);

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
            sound.timeResumeAppTime = app.timestamp;

            // Stopping the sound to start a new one at the right position
            // was the only way I found to get consistent behaviour.

            soloud.stop(sound.soloudHandle);

            var data:SoloudAudioData = cast sound.source.data;
            if (data.isStream) {
                sound.soloudHandle = soloud.play(data.wavStream, sound.volume * VOLUME_FACTOR, sound.pan, false);
            } else {
                sound.soloudHandle = soloud.play(data.wav, sound.volume * VOLUME_FACTOR, sound.pan, false);
            }
            soloud.setLooping(sound.soloudHandle, sound.loop);
            soloud.seek(sound.soloudHandle, time);
            soloud.setRelativePlaySpeed(sound.soloudHandle, sound.pitch);
        }

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

        soloud.setPause(sound.soloudHandle, true);

    }

    public function unPause(handle:AudioHandle):Void {

        var sound = soundOf(handle);
        if (sound == null)
            return;
        if (sound.state != PAUSED)
            return;

        Log.debug('Audio / unpause handle=$handle, ' + sound.source.data.id);

        sound.timeResume = sound.timePause >= 0 ? sound.timePause : 0;
        sound.timeResumeAppTime = app.timestamp;
        sound.timePause = -1;

        soloud.setPause(sound.soloudHandle, false);

        sound.state = PLAYING;

    }

    public function positionOf(handle:AudioHandle):Float {

        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        switch sound.state {
            case INVALID | STOPPED:
                return 0.0;
            case PLAYING | PAUSED:
                var time = switch sound.state {
                    case PAUSED: sound.timePause;
                    case PLAYING: sound.timeResume + (app.timestamp - sound.timeResumeAppTime) * sound.pitch;
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

        return 0.0;

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

    public function volumeOf(handle:AudioHandle):Float {

        var sound = soundOf(handle);
        if (sound == null) return 0.0;

        return sound.volume;

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

    override function isSynchronous():Bool {

        return true;

    }

    override function loadData(path:String, isStream:Bool, format:AudioFormat, async:Bool = false, ?callback:(data:AudioData)->Void):AudioData {

        if (path == null)
            throw 'path is null!';

        if (format == null)
            format = AudioFormat.fromPath(path);

        if (async) {
            Clay.app.backgroundQueue.schedule(function() {
                var data = loadData(path, isStream, format, false);
                Runner.runInMain(function() {
                    if (callback != null) {
                        Immediate.push(() -> {
                            callback(data);
                        });
                    }
                });
            });
            return null;
        }

        var data:AudioData = switch format {
            case WAV | OGG | MP3 | FLAC: audioDataFromFile(app, path, isStream, format);
            case _: null;
        }

        if (callback != null) {
            Immediate.push(() -> {
                callback(data);
            });
        }
        return data;

    }

    /** Returns an AudioData instance from the given bytes */
    public static function dataFromBytes(app:Clay, id:String, bytes:Uint8Array, ?format:AudioFormat):AudioData {

        if (id == null)
            throw 'id is null!';
        if (bytes == null)
            throw 'bytes is null!';

        if (format == null) format = AudioFormat.fromPath(id);

        var info = switch format {
            case WAV | OGG | MP3 | FLAC: audioDataFromBytes(app, id, bytes, format);
            case _: null;
        }

        return info;

    }

    static function audioDataFromFile(app:Clay, path:String, isStream:Bool, format:AudioFormat):AudioData {

        var wav:Wav = untyped __cpp__('NULL');
        var wavStream:WavStream = untyped __cpp__('NULL');

        if (format == null)
            format = AudioFormat.fromPath(path);

        var length:Int = 0;
        var duration:Float = 0;
        var numChannels:Int = 1;
        var sampleRate:Float = 0;

        if (isStream) {
            wavStream = WavStream.create();

            #if android
            var result;
            if (path.startsWith('assets/')) {
                // On android, soloud is not capable of directly reading the assets folder files,
                // so we first extract the asset file to a place exploitable by soloud and use that.
                var extractedPath = Path.join([app.io.appPathPrefs(), 'clay', 'extracted', path]);
                var extractedPathDir = Path.directory(extractedPath);
                if (FileSystem.exists(extractedPathDir) && !FileSystem.isDirectory(extractedPathDir)) {
                    FileSystem.deleteFile(extractedPathDir);
                }
                if (!FileSystem.exists(extractedPathDir)) {
                    FileSystem.createDirectory(extractedPathDir);
                }
                if (!FileSystem.exists(extractedPath)) {
                    var bytes = app.io.loadData(path, true);
                    File.saveBytes(extractedPath, bytes.toBytes());
                }
                result = wavStream.load(extractedPath);
            }
            else {
                result = wavStream.load(path);
            }
            #else
            var result = wavStream.load(path);
            #end

            if (result != 0) {
                var error:SoloudErrors = result;
                Log.error('audio stream error $error at path $path');
                wavStream.destroy();
                return null;
            }

            length = wavStream.mSampleCount;
            duration = wavStream.getLength();
            numChannels = wavStream.mChannels;
            sampleRate = wavStream.mBaseSamplerate;
        }
        else {
            wav = Wav.create();

            #if android
            var result;
            if (path.startsWith('assets/')) {
                // On android, soloud is not capable of directly reading the assets folder files,
                // so we first read the file via clay/sdl and give soloud the raw data directly
                var bytes = app.io.loadData(path, true);
                result = wav.loadMem(untyped __cpp__('(unsigned char*)&{0}[0]', bytes.buffer), bytes.length);
            }
            else {
                result = wav.load(path);
            }
            #else
            var result = wav.load(path);
            #end

            if (result != 0) {
                var error:SoloudErrors = result;
                Log.error('audio error $error at path $path');
                wav.destroy();
                return null;
            }

            length = wav.mSampleCount;
            duration = wav.getLength();
            numChannels = wav.mChannels;
            sampleRate = wav.mBaseSamplerate;
        }

        var data = new SoloudAudioData(
            app, {
                id: path,
                isStream: isStream,
                format: format,
                samples: null,
                length: length,
                channels: numChannels,
                duration: duration,
                rate: Std.int(sampleRate)
            }
        );
        if (isStream)
            data.wavStream = wavStream;
        else
            data.wav = wav;

        return data;

    }

    static function audioDataFromBytes(app:Clay, id:String, bytes:Uint8Array, format:AudioFormat):AudioData {

        var wav:Wav = untyped __cpp__('NULL');

        var length:Int = 0;
        var duration:Float = 0;
        var numChannels:Int = 1;
        var sampleRate:Float = 0;

        wav = Wav.create();
        wav.loadMem(untyped __cpp__('(unsigned char*)&{0}[0]', bytes.buffer), bytes.length);

        length = wav.mSampleCount;
        duration = wav.getLength();
        numChannels = wav.mChannels;
        sampleRate = wav.mBaseSamplerate;

        var data = new SoloudAudioData(
            app, {
                id: id,
                isStream: false,
                format: format,
                samples: null,
                length: length,
                channels: numChannels,
                duration: duration,
                rate: Std.int(sampleRate)
            }
        );
        data.wav = wav;

        return data;

    }

}