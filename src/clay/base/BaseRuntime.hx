package clay.base;

class BaseRuntime {

    /**
     * Clay app
     */
    public var app(default, null):Clay;

    public var name(default, null):String = null;

    function new(app:Clay) {

        this.app = app;

    }

    public function init():Void {}

    public function shutdown(immediate:Bool = false):Void {}

    public function handleReady():Void {}

    public function run():Bool {

        return true;

    }

    public function windowDevicePixelRatio():Float {

        return 1.0;

    }

}
