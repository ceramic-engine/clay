package clay.base;

#if ceramic
import ceramic.Path;
#else
import haxe.io.Path;
#end

import clay.audio.AudioData;
import clay.audio.AudioEvent;
import clay.audio.AudioFormat;
import clay.audio.AudioHandle;

class BaseAudio {

    /**
     * Clay app
     */
    public var app(default, null):Clay;

    function new(app:Clay) {

        this.app = app;

    }

    public function isSynchronous():Bool {

        return false;

    }

    public function init():Void {}

    public function ready():Void {}

    public function tick(delta:Float):Void {}

    public function shutdown():Void {}

    public function loadData(path:String, isStream:Bool, format:AudioFormat, async:Bool = false, ?callback:(data:AudioData)->Void):AudioData {

        if (callback != null) {
            Immediate.push(() -> {
                callback(null);
            });
        }
        return null;

    }

    inline public function emitAudioEvent(event:AudioEvent, handle:AudioHandle):Void {

        app.events.audioEvent(event, handle);

    }

}
