package clay.audio;

/** The type of format data for audio */
enum abstract AudioFormat(Null<Int>) from Null<Int> to Null<Int> {

    var UNKNOWN  = 0;
    var CUSTOM   = 1;
    var OGG      = 2;
    var WAV      = 3;
    var PCM      = 4;

    inline function toString() {
        return switch(this) {
            case UNKNOWN:   'UNKNOWN';
            case CUSTOM:    'CUSTOM';
            case OGG:       'OGG';
            case WAV:       'WAV';
            case PCM:       'PCM';
            case _:         '$this';
        }
    }

    /** Uses the extension of the given path to return the `AudioFormat` */
    public inline static function fromPath(path:String):AudioFormat {

        #if ceramic
        var ext = ceramic.Path.extension(path);
        #else
        var ext = haxe.io.Path.extension(path);
        #end
        return switch ext.toLowerCase() {
            case 'wav': WAV;
            case 'ogg': OGG;
            case 'pcm': PCM;
            case _:     UNKNOWN;
        }

    }

}