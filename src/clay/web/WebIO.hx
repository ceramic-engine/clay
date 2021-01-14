package clay.web;

import clay.buffers.Uint8Array;
import clay.base.BaseIO;

class WebIO extends BaseIO {

    #if clay_web_use_electron_fs
    var testedElectronAvailability:Bool = false;
    var electron:Dynamic = null;
    #end

    override function isSynchronous():Bool {

        #if clay_web_use_electron_fs

        bindElectron();

        return (electron != null);

        #else

        return false;

        #end

    }

    override function loadData(path:String, ?options:Dynamic, ?callback:(data:Uint8Array)->Void):Uint8Array {

        if (path == null)
            throw 'Path is null!';

        var binary:Bool = options != null ? options.binary : false;

        #if clay_web_use_electron_fs

        bindElectron();

        if (electron != null && !path.startsWith('http://') && !path.startsWith('https://')) {

            var fs = js.Syntax.code("{0}.remote.require('fs')", electron);
            var cwd = js.Syntax.code("{0}.remote.process.cwd()", electron);

            try {
                var result = fs.readFileSync(_path);

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

        #end

        var async = true;

        var request = new js.html.XMLHttpRequest();
        request.open("GET", path, async);

        if (binary) {
            request.overrideMimeType('text/plain; charset=x-user-defined');
        } else {
            request.overrideMimeType('text/plain; charset=UTF-8');
        }

        // Only async can set this type
        if (async) {
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
                Log.error('Request status was ${request.status} / ${request.statusText}');
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

/// Internal

    #if clay_web_use_electron_fs

    inline function bindElectron():Void {

        if (!testedElectronAvailability) {
            testedElectronAvailability = true;
            try {
                electron = js.Syntax.code("require('electron')");
            }
            catch (e:Dynamic) {}
        }

    }

    #end

}
