package clay.graphics;

import clay.buffers.Uint8Array;
import clay.Types;

/**
 * A high level texture object to make it easier to manage textures
 */
class Texture extends Resource {

    static var _nextIndex:Int = 1;

    public var index(default, null):Int;

    public var textureId(default, null):TextureId = Graphics.NO_TEXTURE;

    /**
     * If set to `true`, the pixels will be premultiplied by their alpha before submit
     */
    public var loadPremultiplyAlpha:Bool = false;

    /**
     * If `true`, the pixels buffer should store compressed image data that the GPU understands
     */
    public var compressed:Bool = false;
    
    /**
     * The GPU texture format (RGBA, RGB...)
     */
    public var format:TextureFormat = RGBA;
    
    /**
     * The GPU texture type (TEXTURE_2D)
     */
    public var type:TextureType = TEXTURE_2D;
    
    /**
     * The GPU data type (UNSIGNED_BYTE)
     */
    public var dataType:TextureDataType = UNSIGNED_BYTE;
    
    /**
     * When creating a texture manually, the width of this texture.
     */
    public var width:Int = -1;
    
    /**
     * When creating a texture manually, the height of this texture.
     */
    public var height:Int = -1;
    
    /**
     * The width of the actual texture, needed when the texture may be padded to POT sizes
     */
    public var widthActual:Int = -1;
    
    /**
     * The height of the actual texture, needed when the texture may be padded to POT sizes
     */
    public var heightActual:Int = -1;
    
    /**
     * When creating a texture manually, the pixels for this texture.
     * Properties `width` and `height` must be defined when providing pixels.
     */
    public var pixels:Null<Uint8Array> = null;

    /**
     * Set the minification filter type (default LINEAR)
     */
    public var filterMin(default, set):TextureFilter = LINEAR;
    function set_filterMin(filterMin:TextureFilter):TextureFilter {
        if (textureId != Graphics.NO_TEXTURE) {
            bind();
            Graphics.setTexture2dMinFilter(filterMin);
        }
        return this.filterMin = filterMin;
    }

    /**
     * Set the magnification filter type (default LINEAR)
     */
    public var filterMag(default, set):TextureFilter = LINEAR;
    function set_filterMag(filterMag:TextureFilter):TextureFilter {
        if (textureId != Graphics.NO_TEXTURE) {
            bind();
            Graphics.setTexture2dMagFilter(filterMag);
        }
        return this.filterMag = filterMag;
    }

    /**
     * Set the s (horizontal) clamp type (default CLAMP_TO_EDGE)
     */
    public var wrapS(default, set):TextureWrap = CLAMP_TO_EDGE;
    function set_wrapS(wrapS:TextureWrap):TextureWrap {
        if (textureId != Graphics.NO_TEXTURE) {
            bind();
            Graphics.setTexture2dWrapS(wrapS);
        }
        return this.wrapS = wrapS;
    }

    /**
     * Set the t (vertical) clamp type (default CLAMP_TO_EDGE)
     */
    public var wrapT(default, set):TextureWrap = CLAMP_TO_EDGE;
    function set_wrapT(wrapT:TextureWrap):TextureWrap {
        if (textureId != Graphics.NO_TEXTURE) {
            bind();
            Graphics.setTexture2dWrapT(wrapT);
        }
        return this.wrapT = wrapT;
    }

    public function new() {

        this.index = _nextIndex++;

    }

    /**
     * Initialize this texture. Must be called before using the actual texture.
     * When calling init(), properties should be defined accordingly.
     */
    public function init() {

        textureId = Graphics.createTextureId();

        if (width > 0 && widthActual <= 0) {
            widthActual = width;
        }

        if (height > 0 && heightActual <= 0) {
            heightActual = height;
        }

        bind();
        Graphics.setTexture2dMinFilter(filterMin);
        Graphics.setTexture2dMagFilter(filterMag);
        Graphics.setTexture2dWrapT(wrapT);
        Graphics.setTexture2dWrapS(wrapS);

        if (pixels != null) {
            if (width <= 0 || height <= 0) {
                throw 'Provided texture pixels with invalid size (width=$width height=$height)';
            }

            submit(pixels);
        }

    }

    public function destroy() {

        if (textureId != Graphics.NO_TEXTURE) {
            Graphics.deleteTexture(textureId);
            textureId = Graphics.NO_TEXTURE;
        }

    }

    /** Bind this texture to its active texture slot,
        and it's texture id to the texture type. Calling this
        repeatedly is fine, as the state is tracked by `Graphics`. */
    public function bind(slot:Int = -1) {

        if (slot != -1)
            Graphics.setActiveTexture(slot);

        switch type {
            case TEXTURE_2D:
                Graphics.bindTexture2d(textureId);
        }

    }

    /**
     * Submit a pixels array to the texture id. Must match the type and format accordingly.
     * @param pixels 
     */
    public function submit(?pixels:Uint8Array) {

        var max = Graphics.maxTextureSize();

        if (pixels == null) {
            pixels = this.pixels;
        }

        if (pixels == null)
            throw 'Cannot submit texture pixels: pixels is null';
        
        if (widthActual > max)
            throw 'Texture actual width bigger than maximum hardware size (width=$widthActual max=$max)';
        if (heightActual > max)
            throw 'Texture actual height bigger than maximum hardware size (height=$heightActual max=$max)';

        bind();

        switch type {
            case TEXTURE_2D:
                if (compressed) {
                    Graphics.submitCompressedTexture2dPixels(0, format, widthActual, heightActual, pixels);
                }
                else {
                    Graphics.submitTexture2dPixels(0, format, widthActual, heightActual, dataType, pixels);
                }
        }

    }

    /** Fetch the pixels from the texture id, storing them in the provided array buffer view.
        Returns image pixels in RGBA format, as unsigned byte (0-255) values only.
        This means that the view must be `w * h * 4` in length, minimum.
        By default, x and y are 0, 0, and the texture `width` and `height`
        are used (not widthActual / heightActual) */
    public function fetch(into:Uint8Array, x:Int = 0, y:Int = 0, w:Int = -1, h:Int = -1):Uint8Array {

        if (w <= 0)
            w = width;
        if (h <= 0)
            h = height;

        bind();

        switch type {
            case TEXTURE_2D:
                Graphics.fetchTexture2dPixels(into, x, y, w, h);
        }

        return into;

    }

}
