package clay;

import clay.buffers.Uint8Array;

@:structInit
class Image {

    /** Image width from source image */
    public var width:Int = 0;
    /** Image height from source image */
    public var height:Int = 0;
    /** The actual width, used when image is automatically padded to POT */
    public var widthActual:Int = 0;
    /** The actual height, used when image is automatically padded to POT */
    public var heightActual:Int = 0;
    /** used bits per pixel */
    public var bitsPerPixel:Int = 4;
    /** source bits per pixel */
    public var sourceBitsPerPixel:Int = 4;
    /** image pixel data */
    public var pixels:Uint8Array = null;

    public function premultiplyAlpha():Void {

        if (bitsPerPixel == 4) {
            
            var pixels = this.pixels;
            var count = pixels.length;
            var index = 0;
    
            while (index < count) {
    
                var r = pixels[index+0];
                var g = pixels[index+1];
                var b = pixels[index+2];
                var a = pixels[index+3] / 255.0;
    
                pixels[index+0] = Std.int(r*a);
                pixels[index+1] = Std.int(g*a);
                pixels[index+2] = Std.int(b*a);
    
                index += 4;
    
            }
        }
        else {
            Log.warning('Can only premultiply alpha on images with 4 bits per pixels (RGBA)');
        }

    }

}
