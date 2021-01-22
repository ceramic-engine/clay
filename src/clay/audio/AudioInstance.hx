package clay.audio;

import clay.buffers.Uint8Array;

class AudioInstance {

    public var source:AudioSource;

    public var handle:AudioHandle;

    public var destroyed:Bool = false;

    /** Create a new instance from the given audio source.
        Usually called via `source.instance()`, not directly. */
    public function new(source:AudioSource, handle:AudioHandle) {

        this.source = source;
        this.handle = handle;
        
    }

    public function hasEnded():Bool {
        
        if (destroyed)
            throw 'Audio / Instance hasEnded queried after being destroyed';

        return source.app.audio.stateOf(handle) == STOPPED;

    }

    public function destroy() {
        
        if (destroyed)
            throw 'Audio / Instance being destroyed more than once';

        source.app.audio.handleInstanceDestroyed(handle);
        source.instanceKilled(this);
        destroyed = true;
        source = null;
        handle = -1;

    }

    public function dataGet(into:Uint8Array, start:Int, length:Int, intoResult:Array<Int>):Array<Int> {

        if (destroyed)
            throw 'Audio / Instance dataGet queried after being destroyed';

        return source.data.portion(into, start, length, intoResult);

    }

    public function dataSeek(toSamples:Int):Bool {

        if (destroyed)
            throw 'Audio / Instance dataSeek queried after being destroyed';

        return source.data.seek(toSamples);

    }
    
}
