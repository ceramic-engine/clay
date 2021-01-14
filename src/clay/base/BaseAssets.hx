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

    public function loadImage(path:String, components:Int = 4, ?callback:(image:Image)->Void):Image {

        if (callback != null) {
            Immediate.push(() -> {
                callback(null);
            });
        }
        return null;

    }

}