package clay.audio;

enum abstract AudioErrorReason(Int) from Int to Int {

    var STOP_ALSOURCE;

    var DETACH_BUFFER;

    var DELETE_ALSOURCE;

    var GEN_BUFFERS;

    var PRE_FILL_BUFFER;

    var POST_FILL_BUFFER;

    var QUEUE_BUFFER;

    var INIT_QUEUE;

    var NEW_BUFFER;

    var ATTACH_BUFFER;

    var PRE_FLUSH_QUEUE;

    var FLUSH_QUEUE;

    var POST_FLUSH_QUEUE;

    var DELETE_BUFFER;

    var QUERY_PROCESSED_BUFFERS;

    var END;

    var PLAY;

    var PAUSE;

    var UNPAUSE;

    var STOP;

    var LOOP;

    var PRE_SOURCE_STOP;

    var SOURCE_UNQUEUE_BUFFER;

    inline function toString():String {

        return switch this {
            case STOP_ALSOURCE: 'STOP_ALSOURCE';
            case DETACH_BUFFER: 'DETACH_BUFFER';
            case DELETE_ALSOURCE: 'DELETE_ALSOURCE';
            case GEN_BUFFERS: 'GEN_BUFFERS';
            case PRE_FILL_BUFFER: 'PRE_FILL_BUFFER';
            case POST_FILL_BUFFER: 'POST_FILL_BUFFER';
            case QUEUE_BUFFER: 'QUEUE_BUFFER';
            case INIT_QUEUE: 'INIT_QUEUE';
            case NEW_BUFFER: 'NEW_BUFFER';
            case ATTACH_BUFFER: 'ATTACH_BUFFER';
            case PRE_FLUSH_QUEUE: 'PRE_FLUSH_QUEUE';
            case FLUSH_QUEUE: 'FLUSH_QUEUE';
            case POST_FLUSH_QUEUE: 'POST_FLUSH_QUEUE';
            case DELETE_BUFFER: 'DELETE_BUFFER';
            case QUERY_PROCESSED_BUFFERS: 'QUERY_PROCESSED_BUFFERS';
            case END: 'END';
            case PLAY: 'PLAY';
            case PAUSE: 'PAUSE';
            case UNPAUSE: 'UNPAUSE';
            case STOP: 'STOP';
            case LOOP: 'LOOP';
            case PRE_SOURCE_STOP: 'PRE_SOURCE_STOP';
            case SOURCE_UNQUEUE_BUFFER: 'SOURCE_UNQUEUE_BUFFER';
            case _: '$this';
        }

    }

}
