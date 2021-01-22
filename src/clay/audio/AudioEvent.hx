package clay.audio;

enum abstract AudioEvent(Int) from Int to Int {

    var END = 0;

    var DESTROYED = 1;

    var DESTROYED_SOURCE = 2;

    inline function toString() {
        return switch(this) {
            case END:                'END';
            case DESTROYED:          'DESTROYED';
            case DESTROYED_SOURCE:   'DESTROYED_SOURCE';
            case _:                  '$this';
        }
    }

}
