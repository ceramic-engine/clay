package clay.audio;

import clay.buffers.Uint8Array;

@:structInit
class AudioDataOptions {

    public var id:String = null;
    public var rate:Null<Int> = null;
    public var length:Null<Int> = null;
    public var channels:Null<Int> = null;
    public var bitsPerSample:Null<Int> = null;
    public var format:AudioFormat = null;
    public var samples:Uint8Array = null;
    public var isStream:Null<Bool> = null;

}

/** An audio data object contains information about audio samples or streams, ready to be used.
    `AudioData` objects typically come from the `app.assets.audio` API or `app.audio.module.data_from_path`,
    since the implemenation details of decoding audio and streams are module level implementation details.
    This is stored by `AudioSource` and `AssetAudio` objects for example. */
@:allow(clay.audio.AudioInstance)
@:structInit
class AudioData {

    /** Access to the snow runtime */
    public var app:Clay;

    /** The associated id for the data */
    public var id:String = 'AudioData';

    /** The sample data bytes, if any (streams don't populate this) */
    public var samples:Uint8Array;

    /** The sample rate in samples per second */
    public var rate:Int = 44100;

    /** The PCM length in samples */
    public var length:Int = 0;

    /** The number of channels for this data */
    public var channels:Int = 1;

    /** The number of bits per sample for this data */
    public var bitsPerSample:Int = 16;

    /** The audio format type of the sample data */
    public var format:AudioFormat = UNKNOWN;

    /** Whether or not this data is a stream of samples */
    public var isStream:Bool = false;

    /** Whether or not this data has been destroyed */
    public var destroyed:Bool = false;

    inline public function new(app:Clay, options:AudioDataOptions) {

        this.app = app;

        if (options.id != null)
            this.id = options.id;

        if (options.rate != null)
            this.rate = options.rate;

        if (options.length != null)
            this.length = options.length;

        if (options.format != null)
            this.format = options.format;

        if (options.channels != null)
            this.channels = options.channels;

        if (options.bitsPerSample != null)
            this.bitsPerSample = options.bitsPerSample;

        if (options.isStream != null)
            this.isStream = options.isStream;

        if (options.samples != null)
            this.samples = options.samples;

        options = null;

    }

/// Public API, typically populated by subclasses

    public function destroy() {

        if (destroyed) return;

        Log.debug('Audio / destroy AudioData `$id`');
        destroyed = true;

        id = null;
        #if clay_native 
        if (samples != null) {
            samples.buffer = null; 
        }
        #end
        samples = null;

    }

/// Internal implementation details, populated by subclasses

    function seek(to:Int):Bool return false;

    function portion(into:Uint8Array, start:Int, len:Int, intoResult:Array<Int>):Array<Int> return intoResult;

    inline function toString() return '{ "AudioData":true, "id":$id, "rate":$rate, "length":$length, "channels":$channels, "format":"$format", "isStream":$isStream }';

 }
