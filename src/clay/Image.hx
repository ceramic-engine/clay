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
            PremultiplyAlpha.premultiplyAlpha(pixels);
        }
        else {
            Log.warning('Can only premultiply alpha on images with 4 bits per pixels (RGBA)');
        }

    }

    public function reversePremultiplyAlpha():Void {

        if (bitsPerPixel == 4) {
            PremultiplyAlpha.reversePremultiplyAlpha(pixels);
        }
        else {
            Log.warning('Can only reverse premultiply alpha on images with 4 bits per pixels (RGBA)');
        }

    }

}
