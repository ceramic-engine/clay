package clay.audio;

class AudioSource {

    public var app:Clay;

    public var data:AudioData;

    /** Streams only: The size in bytes of a single stream buffer.
        This is ~1 sec in 16 bit mono. default:176400
        for most cases this can be left alone. */
    public var streamBufferLength:Int = 176400;

    /** Streams only: The number of buffers to queue up. default:2
        For most cases this can be left alone. */
    public var streamBufferCount:Int = 2;

    /** Whether this source has been destroyed */
    public var destroyed:Bool = false;

    /** A unique key for this source  */
    public var sourceId:String;

    /** Local list of instances spawned from this source.
        used when destroying the source, to take instances with it. */
    var instances:Array<AudioInstance>;

    public function new(app:Clay, data:AudioData) {

        this.app = app;
        this.data = data;
        this.sourceId = Utils.uniqueId();

        Log.debug('AudioSource / `${this.sourceId}` / ${this.data.id}');

        instances = [];

        if (data.duration <= 0) {
            data.duration = bytesToSeconds(data.length);
        }

    }

    /** Called by the audio system to obtain a new instance of this source. */
    public function instance(handle:AudioHandle):AudioInstance {

        var instance = new AudioInstance(this, handle);

        if (instances.indexOf(instance) == -1) {
            instances.push(instance);
        }

        return instance;

    }

    /** A helper for converting bytes to seconds for a sound source */
    public function bytesToSeconds(bytes:Int):Float {
        var word = data.bitsPerSample == 16 ? 2 : 1;
        var sampleFrames = (data.rate * data.channels * word);

        return bytes / sampleFrames;

    }

    /** A helper for converting seconds to bytes for this audio source */
    public function secondsToBytes(seconds:Float):Int {

        var word = (data.bitsPerSample == 16) ? 2 : 1;
        var sampleFrames = (data.rate * data.channels * word);

        return Std.int(seconds * sampleFrames);

    }

    public function getDuration():Float {

        return data.duration;

    }

    public function destroy() {

        if (destroyed) {
            Log.debug('AudioSource / destroying already destroyed source!');
            return;
        }

        destroyed = true;

        var c = instances.length;
        var i = 0;

        Log.debug('AudioSource / destroy / $sourceId / ${data.id}, stream=${data.isStream}, instances=$c');

        while (i < c) {
            var instance = instances.pop();
            instance.destroy();
            instance = null;
            i++;
        }

        app.audio.handleSourceDestroyed(this);

        data.destroy();
        data = null;
        instances = null;
        app = null;

    }

    @:allow(clay.audio.AudioInstance)
    function instanceKilled(instance:AudioInstance) {

        instances.remove(instance);

    }

}
