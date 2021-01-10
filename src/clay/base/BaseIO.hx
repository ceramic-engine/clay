package clay.base;

import clay.buffers.Uint8Array;

class BaseIO {

    /**
     * Clay app
     */
    public var app(default, null):Clay;

    function new(app:Clay) {

        this.app = app;

    }

    public function init():Void {}

    public function shutdown():Void {}

    public function isSynchronous():Bool {

        return false;

    }
    
    public function appPath():String {

        return null;

    }
    
    public function loadData(path:String, ?options:Dynamic, ?callback:(data:Uint8Array)->Void):Uint8Array {

        if (callback != null) {
            Immediate.push(() -> {
                callback(null);
            });
        }
        return null;

    }

}
