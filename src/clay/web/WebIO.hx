package clay.web;

import clay.base.BaseIO;
import clay.buffers.Uint8Array;

using StringTools;

class WebIO extends BaseIO {

    #if clay_web_use_electron_fs
    var testedElectronRemoteAvailability:Bool = false;
    var electronRemote:Dynamic = null;
    #end

    override function isSynchronous():Bool {

        #if clay_web_use_electron_fs

        bindElectronRemote();

        return (electronRemote != null);

        #else

        return false;

        #end

    }

    override function loadData(path:String, binary:Bool = false, async:Bool = false, ?callback:(data:Uint8Array)->Void):Uint8Array {

        if (path == null)
            throw 'Path is null!';

        #if clay_web_use_electron_fs

        bindElectronRemote();

        if (electronRemote != null && !path.startsWith('http://') && !path.startsWith('https://')) {

            var fs = js.Syntax.code("{0}.require('fs')", electronRemote);
            var cwd = js.Syntax.code("{0}.process.cwd()", electronRemote);

            if (!async) {
                try {
                    var result = fs.readFileSync(path);

                    // Copy data and get rid of nodejs buffer
                    var data = new Uint8Array(result.length);
                    for (i in 0...result.length) {
                        data[i] = js.Syntax.code("{0}[{1}]", result, i);
                    }

                    if (callback != null) {
                        Immediate.push(() -> {
                            callback(data);
                        });
                    }
                    return data;
                }
                catch (e:Dynamic) {
                    Log.error('failed to read file at path $path: ' + e);
                    if (callback != null) {
                        Immediate.push(() -> {
                            callback(null);
                        });
                    }
                    return null;
                }
            }
            else {
                fs.readFile(path, function(err, result) {
                    try {
                        if (err == null) {
                            // Copy data and get rid of nodejs buffer
                            var data = new Uint8Array(result.length);
                            for (i in 0...result.length) {
                                data[i] = js.Syntax.code("{0}[{1}]", result, i);
                            }

                            if (callback != null) {
                                Immediate.push(() -> {
                                    callback(data);
                                });
                            }
                        }
                        else {
                            Log.error('failed to read file at path $path: ' + err);
                        }
                    }
                    catch (e:Dynamic) {
                        Log.error('failed to read file at path $path: ' + e);
                        if (callback != null) {
                            Immediate.push(() -> {
                                callback(null);
                            });
                        }
                    }
                });
            }

            return null;

        }
        else {

        #end

        var asyncHttp = true;

        var request = new js.html.XMLHttpRequest();
        request.open("GET", path, asyncHttp);

        if (binary) {
            request.overrideMimeType('text/plain; charset=x-user-defined');
        } else {
            request.overrideMimeType('text/plain; charset=UTF-8');
        }

        // Only async can set this type
        if (asyncHttp) {
            request.responseType = js.html.XMLHttpRequestResponseType.ARRAYBUFFER;
        }

        request.onload = function(data) {

            if (request.status == 200) {
                var data = new Uint8Array(request.response);
                if (callback != null) {
                    Immediate.push(() -> {
                        callback(data);
                    });
                }
            } else {
                Log.error('Request status for path $path was ${request.status} / ${request.statusText}');
                if (callback != null) {
                    Immediate.push(() -> {
                        callback(data);
                    });
                }
            }
        };

        request.send();

        return null;

        #if clay_web_use_electron_fs
        }
        #end

    }

    #if clay_web_use_electron_fs

    /**
     * Inside Electron, the same folder as `SDL_GetPrefPath` gives a native
     * build of the app: `<appData>/<org>/<app>/` on macOS
     * (`~/Library/Application Support`) and Windows (`%APPDATA%`),
     * `$XDG_DATA_HOME/<org>/<app>/` (else `~/.local/share/...`) on Linux.
     * The folder is created when missing, and the path ends with a
     * separator, like SDL's. `null` outside Electron.
     */
    override function appPathPrefs():String {

        bindElectronRemote();

        if (electronRemote == null)
            return null;

        try {
            final process:Dynamic = js.Syntax.code("{0}.process", electronRemote);
            final path:Dynamic = js.Syntax.code("{0}.require('path')", electronRemote);
            final fs:Dynamic = js.Syntax.code("{0}.require('fs')", electronRemote);
            final platform:String = process.platform;

            var base:String = null;
            if (platform == 'linux') {
                final xdg:String = process.env.XDG_DATA_HOME;
                if (xdg != null && xdg != '') {
                    base = xdg;
                }
                else {
                    final os:Dynamic = js.Syntax.code("{0}.require('os')", electronRemote);
                    base = path.join(os.homedir(), '.local', 'share');
                }
            }
            else {
                base = js.Syntax.code("{0}.app.getPath('appData')", electronRemote);
            }

            final appId = Clay.app.appId;
            final storageName = Clay.app.appStorageName;
            final org = StorageNames.prefOrg(appId, storageName);
            final name = StorageNames.prefApp(appId, storageName);

            final dir:String = org != '' ? path.join(base, org, name) : path.join(base, name);
            js.Syntax.code("{0}.mkdirSync({1}, {recursive: true})", fs, dir);
            return dir + path.sep;
        }
        catch (e:Dynamic) {
            return null;
        }

    }

    #end

/// Internal

    #if clay_web_use_electron_fs

    inline function bindElectronRemote():Void {

        if (!testedElectronRemoteAvailability) {
            testedElectronRemoteAvailability = true;
            try {
                electronRemote = js.Syntax.code("require('@electron/remote')");
            }
            catch (e:Dynamic) {}
        }

    }

    #end

}
