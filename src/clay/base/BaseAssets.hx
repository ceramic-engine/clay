package clay.base;

#if ceramic
import ceramic.Path;
#else
import haxe.io.Path;
#end

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

    public function fullPath(path:String):String {

        if (Path.isAbsolute(path)) {
            return path;
        }
        else {
            #if (ios || tvos)
            // This is because of how the files are put into the xcode project
            // for the iOS builds, it stores them inside of /assets to avoid
            // including the root in the project in the Resources/ folder
            return Path.join([app.io.appPath(), 'assets', path]);
            #else
            return Path.join([app.io.appPath(), path]);
            #end
        }

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