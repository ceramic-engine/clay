package clay.base;

class BaseAssets {

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

}