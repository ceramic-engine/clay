package clay.native;

import clay.buffers.Uint8Array;
import clay.base.BaseAssets;

class NativeAssets extends BaseAssets {

    override function isSynchronous():Bool {

        return true;

    }

    override function loadImage(path:String, components:Int = 4, ?callback:(image:Image)->Void):Image {

        if (path == null)
            throw 'Image path is null!';

        // Get binary data
        var bytes:Uint8Array = null;
        bytes = app.io.loadData(path, true);
        if (bytes == null) {
            if (callback != null) {
                Immediate.push(() -> {
                    callback(null);
                });
            }
            return null;
        }

        // Decode binary data into image
        var image = imageFromBytes(bytes, components);
        if (callback != null) {
            Immediate.push(() -> {
                callback(image);
            });
        }
        return image;

    }

    public function imageFromBytes(bytes:Uint8Array, components:Int = 4, ?callback:(image:Image)->Void):Image {

        if (bytes == null)
            throw 'Image bytes are null!';

        var info = stb.Image.load_from_memory(bytes.buffer, bytes.length, components);

        if (info == null) {
            if (callback != null) {
                Immediate.push(() -> {
                    callback(null);
                });
            }
            return null;
        }

        // var _pixel_bytes : haxe.io.Bytes = haxe.io.Bytes.ofData(_info.bytes);

        var image:Image = {
            width: info.w,
            height: info.h,
            widthActual: info.w,
            heightActual: info.h,
            sourceBitsPerPixel: info.comp,
            bitsPerPixel: info.req_comp,
            pixels: Uint8Array.fromBuffer(info.bytes, 0, info.bytes.length)
        };
        if (callback != null) {
            Immediate.push(() -> {
                callback(image);
            });
        }
        return image;

    }

}