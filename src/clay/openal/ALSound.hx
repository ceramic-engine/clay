package clay.openal;

import clay.Types;
import clay.audio.AudioErrorReason;
import clay.audio.AudioInstance;
import clay.audio.AudioSource;
import clay.openal.AL;
import clay.openal.OpenALAudio;

@:allow(clay.openal.OpenALAudio)
class ALSound {

    public var instance:AudioInstance;
    public var source:AudioSource;
    public var audio:OpenALAudio;

    public var alsource:Int;
    public var alformat:Int;

    /** The current pan in -1,1 range */
    var pan:Float = 0.0;

    var looping:Bool = false;

    var currentTime:Float = 0.0;

    public function new(audio:OpenALAudio, source:AudioSource, instance:AudioInstance) {

        this.audio = audio;
        this.source = source;
        this.instance = instance;

        alsource = newSource();
        alformat = sourceFormat();

    }

    public function init() {

        var buffer:ALuint = audio.buffers.get(source.sourceId);

        if (buffer == AL.NONE) {

            var data = source.data;

            buffer = AL.genBuffer();

            Log.debug('Audio / new buffer ${data.id} / format ${alformat} / buffer $buffer');

            if (data.samples != null) {
                AL.bufferData(buffer, alformat, data.rate, data.samples.buffer, data.samples.byteOffset, data.samples.byteLength);
            } else {
                buffer = AL.NONE;
                Log.debug('Audio / new buffer ${data.id} / created with AL.NONE buffer!');
            }

            ensureNoError(NEW_BUFFER);

            Log.debug('Audio / new buffer made for source / ${source.data.id} / ${source.sourceId} / $buffer');

            audio.buffers.set(source.sourceId, buffer);

        }
        else {

            Log.debug('Audio / existing buffer found for source / ${source.data.id} / ${source.sourceId} / $buffer');

        }

        AL.sourcei(alsource, AL.BUFFER, buffer);

        ensureNoError(ATTACH_BUFFER);

    }

    function setPosition(time:Float) {

        AL.sourcef(alsource, AL.SEC_OFFSET, time);

    }

    function getPosition() {

        return AL.getSourcef(alsource, AL.SEC_OFFSET);

    }

    public function destroy() {

        // Clear error state
        AL.getError();

        if (AL.getSourcei(alsource, AL.SOURCE_STATE) == AL.PLAYING) {
            AL.sourceStop(alsource);
            ensureNoError(STOP_ALSOURCE);
        }

        // Detach buffer
        if (AL.getSourcei(alsource, AL.BUFFER) != 0) {
            AL.sourcei(alsource, AL.BUFFER, 0);
            ensureNoError(DETACH_BUFFER);
        }

        AL.deleteSource(alsource);

        ensureNoError(DELETE_ALSOURCE);

    }

    public function tick(delta:Float):Void {

        //

    }

/// Internal

    inline function newSource() : Int {
        var source = AL.genSource();
        AL.sourcef(source, AL.GAIN, 1.0);
        AL.sourcei(source, AL.LOOPING, AL.FALSE);
        AL.sourcef(source, AL.PITCH, 1.0);
        AL.source3f(source, AL.POSITION, 0.0, 0.0, 0.0);
        AL.source3f(source, AL.VELOCITY, 0.0, 0.0, 0.0);
        return source;
    }

    inline function ensureNoError(reason:AudioErrorReason, ?pos:haxe.PosInfos) {
        audio.ensureNoError(reason, pos);
    }

    function sourceFormat() {

        var format = AL.FORMAT_MONO16;

        if (source.data.channels > 1) {
            if (source.data.bitsPerSample == 8) {
                format = AL.FORMAT_STEREO8;
                Log.debug('Audio / source format: stereo 8');
            } else {
                format = AL.FORMAT_STEREO16;
                Log.debug('Audio / source format: stereo 16');
            }
        }
        else { //mono
            if (source.data.bitsPerSample == 8) {
                format = AL.FORMAT_MONO8;
                Log.debug('Audio / source format: mono 8');
            } else {
                format = AL.FORMAT_MONO16;
                Log.debug('Audio / source format: mono 16');
            }
        }

        return format;

    }

}
