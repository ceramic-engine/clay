package clay.audio;

enum abstract AudioState(Int) from Int to Int {

    var INVALID  = -1;

    var PAUSED   = 0;

    var PLAYING  = 1;

    var STOPPED  = 2;

    inline function toString() {
        return switch(this) {
            case INVALID:    'INVALID';
            case PAUSED:     'PAUSED';
            case PLAYING:    'PLAYING';
            case STOPPED:    'STOPPED';
            case _:          '$this';
        }
    }

}
