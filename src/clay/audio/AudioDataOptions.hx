package clay.audio;

import clay.buffers.Uint8Array;

/** Options for constructing an AudioData instance */
typedef AudioDataOptions = {

    @:optional var id:String;

    @:optional var rate:Int;
    @:optional var length:Int;
    @:optional var channels:Int;
    @:optional var bitsPerSample:Int;
    @:optional var format:AudioFormat;
    @:optional var samples:Uint8Array;
    @:optional var isStream:Bool;

}
