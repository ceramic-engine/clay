package clay.base;

#if ceramic
import ceramic.Path;
#else
import haxe.io.Path;
#end

using StringTools;

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
            var appPath = app.io.appPath();

            // Scheme-style base paths (e.g. SDL3 returns `assets://` for the
            // app's assets on android) must not go through Path.join, which
            // would collapse their double slash and make the scheme
            // unrecognizable to the underlying IO
            var schemeIndex = appPath != null ? appPath.indexOf('://') : -1;
            if (schemeIndex != -1) {
                var prefix = appPath;
                if (!prefix.endsWith('/')) {
                    prefix += '/';
                }
                #if (ios || tvos)
                return prefix + 'assets/' + path;
                #else
                return prefix + path;
                #end
            }

            #if (ios || tvos)
            // This is because of how the files are put into the xcode project
            // for the iOS builds, it stores them inside of /assets to avoid
            // including the root in the project in the Resources/ folder
            return Path.join([appPath, 'assets', path]);
            #else
            return Path.join([appPath, path]);
            #end
        }

    }

    public function loadImage(path:String, components:Int = 4, async:Bool = false, ?callback:(image:Image)->Void):Image {

        if (callback != null) {
            Immediate.push(() -> {
                callback(null);
            });
        }
        return null;

    }

}