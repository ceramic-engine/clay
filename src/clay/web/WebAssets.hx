package clay.web;

import clay.base.BaseAssets;
import clay.buffers.Uint8Array;
#if ceramic
import ceramic.Path;
#else
import haxe.io.Path;
#end


class WebAssets extends BaseAssets {

    #if clay_web_use_electron_pngjs
    var testedElectronPngjsAvailability:Bool = false;
    var electron:Dynamic = null;
    var pngjs:Dynamic = null;
    #end

    override function isSynchronous():Bool {

        return false;

    }

    override function loadImage(path:String, components:Int = 4, async:Bool = false, ?callback:(image:Image)->Void):Image {

        if (path == null)
            throw 'Image path is null!';

        var ext = Path.extension(path);

        #if clay_web_use_electron_pngjs
        bindElectronPngjs();

        if (pngjs != null && ext == 'png' && !async) {

            if (app.io.isSynchronous()) {
                var bytes = app.io.loadData(path, true);
                if (bytes == null) {
                    if (callback != null) {
                        Immediate.push(() -> {
                            callback(null);
                        });
                    }
                    return null;
                }
                var image = decodePngWithPngjs(bytes);
                if (callback != null) {
                    Immediate.push(() -> {
                        callback(image);
                    });
                }
                return image;
            }
            else {
                app.io.loadData(path, true, function(bytes) {
                    if (bytes == null) {
                        if (callback != null) {
                            Immediate.push(() -> {
                                callback(null);
                            });
                        }
                    }
                    else {
                        var image = decodePngWithPngjs(bytes);
                        if (callback != null) {
                            Immediate.push(() -> {
                                callback(image);
                            });
                        }
                    }
                });
                return null;
            }
        }

        #end

        app.io.loadData(path, true, function(bytes) {

            if (bytes == null) {
                if (callback != null) {
                    Immediate.push(() -> {
                        callback(null);
                    });
                }
                return;
            }

            imageFromBytesUsingImageElement(bytes, ext, 4, function(image) {
                if (callback != null) {
                    Immediate.push(() -> {
                        callback(image);
                    });
                }
            });
        });
        return null;

    }

    #if clay_web_use_electron_pngjs

    public function decodePngWithPngjs(bytes:Uint8Array, pot:Bool = true):Image {

        try {
            var Buffer = js.Syntax.code("{0}.remote.require('buffer').Buffer", electron);
            var pngjsInfo = pngjs.PNG.sync.read(Buffer.from(bytes));

            var widthActual = pot ? nearestPowerOfTwo(pngjsInfo.width) : pngjsInfo.width;
            var heightActual = pot ? nearestPowerOfTwo(pngjsInfo.height) : pngjsInfo.height;

            // Copy data and get rid of nodejs buffer
            var bufferData = pngjsInfo.data;
            var pngjsData = new Uint8Array(bufferData.length);
            for (i in 0...bufferData.length) {
                pngjsData[i] = js.Syntax.code("{0}[{1}]", bufferData, i);
            }

            var imageBytes = paddedBytesFromPixels(pngjsInfo.width, pngjsInfo.height, widthActual, heightActual, pngjsData);

            var image:Image = {
                width: pngjsInfo.width,
                height: pngjsInfo.height,
                widthActual: widthActual,
                heightActual: heightActual,
                sourceBitsPerPixel: 4,
                bitsPerPixel: 4,
                pixels: imageBytes
            };

            imageBytes = null;
            bufferData = null;

            return image;

        }
        catch (e:Dynamic) {
            Log.error('failed to decode png: $e');
        }

        return null;

    }

    #end

    /** Create an image info (padded to POT) from a given Canvas or Image element. */
    public function decodeImageFromElement(elem:js.html.ImageElement, pot:Bool = true):Image {

        var widthActual = pot ? nearestPowerOfTwo(elem.width) : elem.width;
        var heightActual = pot ? nearestPowerOfTwo(elem.height) : elem.height;
        var imageBytes = paddedBytesFromElement(elem.width, elem.height, widthActual, heightActual, elem);

        var image:Image = {
            width: elem.width,
            height: elem.height,
            widthActual: widthActual,
            heightActual: heightActual,
            sourceBitsPerPixel: 4,
            bitsPerPixel: 4,
            pixels: imageBytes
        };

        imageBytes = null;

        return image;

    }

    public function imageFromBytes(bytes:Uint8Array, ext:String, components:Int = 4, pot:Bool = true, ?callback:(image:Image)->Void):Image {

        #if clay_web_use_electron_pngjs
        bindElectronPngjs();

        if (pngjs != null && ext == 'png' && components == 4) {
            var image = decodePngWithPngjs(bytes, pot);
            callback(image);
            return image;
        }
        else {
        #end
            return imageFromBytesUsingImageElement(bytes, ext, components, pot, callback);
        #if clay_web_use_electron_pngjs
        }
        #end

    }

    public function imageFromBytesUsingImageElement(bytes:Uint8Array, ext:String, components:Int = 4, pot:Bool = true, ?callback:(image:Image)->Void):Image {

        if (bytes == null)
            throw 'Image bytes are null!';

        // Convert to a binary string
        var str = '', i = 0, len = bytes.length;
        while (i < len) str += String.fromCharCode(bytes[i++] & 0xff);

        var b64 = js.Browser.window.btoa(str);
        var src = 'data:image/$ext;base64,$b64';

        // Convert to an image element
        var img = new js.html.Image();

        img.onload = function(_) {
            var image = decodeImageFromElement(img, pot);
            if (callback != null) {
                Immediate.push(() -> {
                    callback(image);
                });
            }
        }

        img.onerror = function(e) {
            Log.error('failed to load image from bytes, on error: $e');
        }

        img.src = src;

        return null;

    }

    /** Return a padded array of bytes from raw image pixels */
    public function paddedBytesFromPixels(width:Int, height:Int, widthPadded:Int, heightPadded:Int, source:Uint8Array):Uint8Array {

        var tmpCanvas = js.Browser.document.createCanvasElement();

        tmpCanvas.width = widthPadded;
        tmpCanvas.height = heightPadded;

        var tmpContext = tmpCanvas.getContext2d();
        tmpContext.clearRect(0, 0, tmpCanvas.width, tmpCanvas.height );

        var imageBytes = null;
        var pixels = new js.lib.Uint8ClampedArray(source.buffer);
        var imgdata = tmpContext.createImageData(width, height);
        imgdata.data.set(pixels);

        try {

            // Store the data in it first
            tmpContext.putImageData(imgdata, 0, 0);
            // Then bring out the full size
            imageBytes = tmpContext.getImageData(0, 0, tmpCanvas.width, tmpCanvas.height);

        }
        catch (e:Dynamic) {

            throw e;

        }

        // Cleanup
        tmpCanvas = null;
        tmpContext = null;
        imgdata = null;

        return Uint8Array.fromView(imageBytes.data);

    }

    /** Return a padded array of bytes from an image/canvas element. */
    public function paddedBytesFromElement(width:Int, height:Int, widthPadded:Int, heightPadded:Int, source:js.html.ImageElement):Uint8Array {

        var tmpCanvas = js.Browser.document.createCanvasElement();

        tmpCanvas.width = widthPadded;
        tmpCanvas.height = heightPadded;

        var tmpContext = tmpCanvas.getContext2d();
        tmpContext.clearRect(0, 0, tmpCanvas.width, tmpCanvas.height);
        tmpContext.drawImage(source, 0, 0, width, height);

        var imageBytes = null;

        try {

            imageBytes = tmpContext.getImageData(0, 0, tmpCanvas.width, tmpCanvas.height);

        }
        catch (e:Dynamic) {

            var tips = '- textures served from file:/// throw security errors\n';
                tips += '- textures served over http:// work for cross origin byte requests';

            Log.info(tips);
            throw e;

        }

        // Cleanup
        tmpCanvas = null;
        tmpContext = null;

        return Uint8Array.fromView(imageBytes.data);

    }

/// Internal

    #if clay_web_use_electron_fs

    inline function bindElectronPngjs():Void {

        if (!testedElectronPngjsAvailability) {
            testedElectronPngjsAvailability = true;
            try {
                electron = js.Syntax.code("require('electron')");
                pngjs = js.Syntax.code("{0}.remote.require('pngjs')", electron);
            }
            catch (e:Dynamic) {}
        }

    }

    #end

    static var POT:Bool = true;

    function nearestPowerOfTwo(value:Int) {

        if (!POT) return value;

        value--;

        value |= value >> 1;
        value |= value >> 2;
        value |= value >> 4;
        value |= value >> 8;
        value |= value >> 16;

        value++;

        return value;

    }

}
