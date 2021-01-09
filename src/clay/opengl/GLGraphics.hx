package clay.opengl;

import clay.buffers.Float32Array;
import clay.buffers.Uint8Array;
import clay.Types;
import clay.opengl.GL;

using clay.Extensions;

/**
 * A set of helpers to interact with GL stuff.
 * Public API is trying to be a bit agnostic so that other
 * non-GL implementations could be replaced fairly easily.
 */
class GLGraphics {

    inline static final DEPTH24_STENCIL8_OES = 0x88F0;

    inline static final TEXTURE_2D_MULTISAMPLE = 0x9100;

    inline public static var NO_TEXTURE:TextureId = #if clay_web null #else 0 #end;

    inline public static var NO_FRAMEBUFFER:GLFramebuffer = #if clay_web null #else 0 #end;

    inline public static var NO_RENDERBUFFER:GLRenderbuffer = #if clay_web null #else 0 #end;

    inline public static var NO_SHADER:GLShader = #if clay_web null #else 0 #end;

    inline public static var NO_PROGRAM:GLProgram = #if clay_web null #else 0 #end;

    inline public static var NO_LOCATION:GLUniformLocation = #if clay_web null #else 0 #end;

    static var _boundTexture2D:Array<TextureId> = [];

    static var _boundProgram:GLProgram = NO_PROGRAM;

    static var _activeTextureSlot:Int = -1;

    static var _boundFramebuffer:GLFramebuffer = NO_FRAMEBUFFER;

    static var _boundRenderbuffer:GLRenderbuffer = NO_RENDERBUFFER;

    static var _didFetchDefaultBuffers:Bool = false;

    static var _defaultFramebuffer:GLFramebuffer = NO_FRAMEBUFFER;

    static var _defaultRenderbuffer:GLRenderbuffer = NO_RENDERBUFFER;

    @:allow(clay.sdl.SDLRuntime)
    @:allow(clay.web.WebRuntime)
    private static function setup():Void {

        _defaultFramebuffer = GL.getParameter(GL.FRAMEBUFFER_BINDING);
        _defaultRenderbuffer = GL.getParameter(GL.RENDERBUFFER_BINDING);
        _didFetchDefaultBuffers = true;

    }

    /**
     * Clear the current render buffer
     * @param r red value (between 0 and 1)
     * @param g green value (between 0 and 1)
     * @param b blue value (between 0 and 1)
     * @param a alpha value (between 0 and 1)
     * @param clearDepth set to `true` (default) to also clear depth buffer, if applicable
     */
    public static function clear(r:Float, g:Float, b:Float, a:Float, clearDepth:Bool = true):Void {

        GL.clearColor(r, g, b, a);

        if (clearDepth && Clay.app.config.render.depth > 0) {
            GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
            GL.clearDepth(1.0);
        } else {
            GL.clear(GL.COLOR_BUFFER_BIT);
        }

    }

    /**
     * Create a new texture and return its identifier
     * @return TextureId
     */
    public inline static function createTextureId():TextureId {

        return GL.createTexture();

    }

    /**
     * Set active texture slot
     * @param slot a slot number. Assigned expression will be `GL.TEXTURE0 + slot` on GL
     */
    public inline static function setActiveTexture(slot:Int):Void {

        if (_activeTextureSlot != slot) {
            _activeTextureSlot = slot;
            while (_boundTexture2D.length <= _activeTextureSlot)
                _boundTexture2D.push(NO_TEXTURE);
            GL.activeTexture(GL.TEXTURE0 + slot);
        }

    }

    /**
     * Delete the texture identified with `textureId` from the GPU
     * @param textureId 
     */
    public inline static function deleteTexture(textureId:TextureId):Void {

        GL.deleteTexture(textureId);

    }

    /**
     * Set current viewport delimited with x, y, width and height
     * @param x The x value to specify lower left corner of viewport
     * @param y The y value to specify lower left corner of viewport
     * @param width The width of the viewport
     * @param height The height of the viewport
     */
    public inline static function setViewport(x:Int, y:Int, width:Int, height:Int):Void {

        GL.viewport(x, y, width, height);

    }

    /**
     * Bind the texture identified by `textureId` to do some work with it
     * @param textureId a valid texture identifier returned by `createTextureId()` or `NO_TEXTURE` to unbind texture
     */
    public inline static function bindTexture2d(textureId:TextureId):Void {

        if (_boundTexture2D.unsafeGet(_activeTextureSlot) != textureId) {
            _boundTexture2D.unsafeSet(_activeTextureSlot, textureId);
            GL.bindTexture(GL.TEXTURE_2D, textureId);
        }

    }

    /**
     * Return the maximum size of a texture from the hardware
     * @return Int
     */
    public inline static function maxTextureSize():Int {

        var size = GL.getParameter(GL.MAX_TEXTURE_SIZE);
        // It seems that on some devices value may be below 0
        // In that case, just use 4096 as save value
        if (size <= 0) {
            size = 4096;
        }

        return size;

    }

    /**
     * Submit compressed texture 2D pixels
     * @param level The level of detail. Level 0 is the base image level. Level n is the nth mipmap reduction image.
     * @param format The texture format (RGBA)
     * @param width The width of the texture to submit
     * @param height The height of the texture to submit
     * @param pixels The pixels buffer when the data will be written to
     */
    public inline static function submitCompressedTexture2dPixels(level:Int, format:TextureFormat, width:Int, height:Int, pixels:Uint8Array):Void {

        GL.compressedTexImage2D(GL.TEXTURE_2D, level, format, width, height, 0, pixels);

    }

    /**
     * Fetch 2d texture pixels
     * @param level The level of detail. Level 0 is the base image level. Level n is the nth mipmap reduction image.
     * @param format The texture format (RGBA)
     * @param width The width of the texture to submit
     * @param height The height of the texture to submit
     * @param dataType The data type of the pixel data (UNSIGNED_BYTE)
     * @param pixels The pixels buffer containing data to submit
     */
    public inline static function submitTexture2dPixels(level:Int, format:TextureFormat, width:Int, height:Int, dataType:TextureDataType, pixels:Uint8Array):Void {

        GL.texImage2D(GL.TEXTURE_2D, level, format, width, height, 0, format, dataType, pixels);

    }

    /**
     * Fetch texture 2d pixels
     * @param into The pixels buffer when the data will be written to
     * @param x The x position of the texture rect to fetch
     * @param y The y position of the texture rect to fetch
     * @param w The width of the texture rect to fetch
     * @param h The height of the texture rect to fetch
     */
    public static function fetchTexture2dPixels(into:Uint8Array, x:Int, y:Int, w:Int, h:Int):Void {
        
        if (into == null)
            throw 'Texture fetch requires a valid buffer to store the pixels.';

        var textureId = _boundTexture2D.unsafeGet(_activeTextureSlot);
        var required = w * h * 4;

        if (into.length < required)
            throw 'Texture fetch requires at least $required (w * h * 4) bytes for the pixels, you have ${into.length}!';

        // GL ES/WebGL spec doesn't include `glGetTexImage`,
        // but we can read the pixels from a temporary frame buffer (render texture) instead
        // This way works on all targets the same.

        var fb = GL.createFramebuffer();

        GL.bindFramebuffer(GL.FRAMEBUFFER, fb);
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, textureId, 0);

        if (GL.checkFramebufferStatus(GL.FRAMEBUFFER) != GL.FRAMEBUFFER_COMPLETE)
            throw 'Incomplete framebuffer'; 

        GL.readPixels(x, y, w, h, GL.RGBA, GL.UNSIGNED_BYTE, into);

        GL.bindFramebuffer(GL.FRAMEBUFFER, NO_FRAMEBUFFER);
        GL.deleteFramebuffer(fb);

        fb = NO_FRAMEBUFFER;

    }

    /**
     * Create a new framebuffer
     * @return Framebuffer
     */
    public inline static function createFramebuffer():GLFramebuffer {

        return GL.createFramebuffer();

    }

    /**
     * Bind a framebuffer to work with it
     * @param framebuffer The framebuffer to bind
     */
    public static function bindFramebuffer(framebuffer:GLFramebuffer):Void {

        if (_boundFramebuffer != framebuffer) {
            _boundFramebuffer = framebuffer;

            if (framebuffer == NO_FRAMEBUFFER)
                framebuffer = _defaultFramebuffer;

            GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer);
        }

    }

    /**
     * Create a new renderbuffer
     * @return Renderbuffer
     */
    public inline static function createRenderbuffer():GLRenderbuffer {

        return GL.createRenderbuffer();

    }

    /**
     * Bind a renderbuffer to work with it
     * @param renderbuffer The renderbuffer to bind
     */
    public static function bindRenderbuffer(renderbuffer:GLRenderbuffer):Void {

        if (_boundRenderbuffer != renderbuffer) {
            _boundRenderbuffer = renderbuffer;

            if (renderbuffer == NO_RENDERBUFFER)
                renderbuffer = _defaultRenderbuffer;

            GL.bindRenderbuffer(GL.RENDERBUFFER, renderbuffer);
        }

    }

    /**
     * Set 2d texture minification filter
     * @param minFilter 
     */
    public inline static function setTexture2dMinFilter(minFilter:TextureFilter):Void {

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, minFilter);

    }

    /**
     * Set 2d texture magnification filter
     * @param magFilter 
     */
    public inline static function setTexture2dMagFilter(magFilter:TextureFilter):Void {

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, magFilter);

    }

    /**
     * Set 2d texture s (horizontal) clamp type
     * @param wrapS 
     */
    public inline static function setTexture2dWrapS(wrapS:TextureWrap):Void {

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrapS);

    }

    /**
     * Set 2d texture t (vertical) clamp type
     * @param wrapT 
     */
    public inline static function setTexture2dWrapT(wrapT:TextureWrap):Void {

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrapT);

    }

    /**
     * Configure storage for the given framebuffer and renderbuffer with the given settings.
     * This helper is a bit higher level to make it easier to configure buffers depending on the platform.
     * @param framebuffer
     * @param renderbuffer
     * @param textureId
     * @param width
     * @param height
     * @param stencil
     * @param antialiasing
     */
    public inline static function configureRenderTargetBuffersStorage(
        renderTarget:GLGraphics_RenderTarget,
        textureId:TextureId, width:Int, height:Int, stencil:Bool, antialiasing:Int
        ):Void {

        var framebuffer = renderTarget.framebuffer;
        var renderbuffer = renderTarget.renderbuffer;

        bindFramebuffer(framebuffer);
        bindRenderbuffer(renderbuffer);

        // Create storage for the depth/stencil buffer
        if (stencil) {
            #if (ios || tvos || android)
            GL.renderbufferStorage(GL.RENDERBUFFER, DEPTH24_STENCIL8_OES, width, height);
            #else
            GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_STENCIL, width, height);
            #end
        }
        else {
            #if (web || ios || tvos || android)
            GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, width, height);
            #else
            GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT, width, height);
            #end
        }

        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, textureId, 0);

        if (stencil) {
            GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_STENCIL_ATTACHMENT, GL.RENDERBUFFER, renderbuffer);
        }
        else {
            GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, renderbuffer);
        }

        // Check status
        var status = GL.checkFramebufferStatus(GL.FRAMEBUFFER);
        switch status {

            case GL.FRAMEBUFFER_COMPLETE:

            case GL.FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
                throw("Incomplete framebuffer: FRAMEBUFFER_INCOMPLETE_ATTACHMENT");

            case GL.FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
                throw("Incomplete framebuffer: FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT");

            case GL.FRAMEBUFFER_INCOMPLETE_DIMENSIONS:
                throw("Incomplete framebuffer: FRAMEBUFFER_INCOMPLETE_DIMENSIONS");

            case GL.FRAMEBUFFER_UNSUPPORTED:
                throw("Incomplete framebuffer: FRAMEBUFFER_UNSUPPORTED");

            default:
                throw("Incomplete framebuffer: " + status);
        }

        // Unbind buffers
        bindFramebuffer(NO_FRAMEBUFFER);
        bindRenderbuffer(NO_RENDERBUFFER);

    }

    /**
     * Create a render target from the given settings
     * @param textureId 
     * @param width 
     * @param height 
     * @param stencil 
     * @param antialiasing 
     */
    public static function createRenderTarget(textureId:TextureId, width:Int, height:Int, stencil:Bool, antialiasing:Int):RenderTarget {

        var renderTarget = new GLGraphics_RenderTarget();

        // Create the framebuffer
        renderTarget.framebuffer = createFramebuffer();

        // Create the renderbuffer
        renderTarget.renderbuffer = createRenderbuffer();

        // Configure buffers storage
        configureRenderTargetBuffersStorage(renderTarget, textureId, width, height, stencil, antialiasing);

        return renderTarget;

    }

    public static function deleteRenderTarget(renderTarget:GLGraphics_RenderTarget):Void {

        if (renderTarget.framebuffer != NO_FRAMEBUFFER) {
            GL.deleteFramebuffer(renderTarget.framebuffer);
            renderTarget.framebuffer = NO_FRAMEBUFFER;
        }

        if (renderTarget.renderbuffer != NO_RENDERBUFFER) {
            GL.deleteFramebuffer(renderTarget.renderbuffer);
            renderTarget.renderbuffer = NO_RENDERBUFFER;
        }

    }

    public inline static function setRenderTarget(renderTarget:GLGraphics_RenderTarget):Void {

        if (renderTarget != null) {
            bindFramebuffer(renderTarget.framebuffer);
            bindRenderbuffer(renderTarget.renderbuffer);
        }
        else {
            bindFramebuffer(NO_FRAMEBUFFER);
            bindRenderbuffer(NO_RENDERBUFFER);
        }

    }

    public inline static function enableBlending():Void {

        GL.enable(GL.BLEND);

    }

    public inline static function disableBlending():Void {

        GL.disable(GL.BLEND);

    }

    public static function createShader(vertSource:String, fragSource:String, ?attributes:Array<String>, ?textures:Array<String>):GpuShader {

        var shader = new GLGraphics_GpuShader();

        shader.vertShader = compileGLShader(GL.VERTEX_SHADER, vertSource);
        if (shader.vertShader == null) {
            deleteShader(shader);
            return null;
        }

        shader.fragShader = compileGLShader(GL.FRAGMENT_SHADER, fragSource);
        if (shader.fragShader == null) {
            deleteShader(shader);
            return null;
        }

        if (!linkShader(shader, attributes)) {
            deleteShader(shader);
            return null;
        }

        // If textures array is provided, define ordered slots
        if (textures != null) {
            configureShaderTextureSlots(shader, textures);
        }

        return shader;

    }

    public static function linkShader(shader:GLGraphics_GpuShader, ?attributes:Array<String>):Bool {

        inline function formatLog(log:String) {
            var items = log.split('\n');
            items = items.filter(function(s) { return StringTools.trim(s) != ''; });
            items = items.map(function(s) { return '\t\t' + StringTools.trim(s); });
            return items.join('\n');
        }

        var program = GL.createProgram();

        GL.attachShader(program, shader.vertShader);
        GL.attachShader(program, shader.fragShader);

        // If attributes array is provided, define ordered locations
        if (attributes != null) {
            for (i in 0...attributes.length) {
                GL.bindAttribLocation(program, i, attributes.unsafeGet(i));
            }
        }

        GL.linkProgram(program);

        if (GL.getProgramParameter(program, GL.LINK_STATUS) == 0) {
            Log.error('\tFailed to link shader program:');
            Log.error(formatLog(GL.getProgramInfoLog(program)));
            GL.deleteProgram(program);
            return false;
        }

        shader.program = program;

        return true;

    }

    public static function configureShaderTextureSlots(shader:GLGraphics_GpuShader, textures:Array<String>):Void {

        useShader(shader);

        for (i in 0...textures.length) {
            var texture = textures.unsafeGet(i);
            var attr = GL.getUniformLocation(shader.program, texture);
            if (attr != NO_LOCATION) {
                GL.uniform1i(attr, i);
                shader.textures[i] = texture;
            }
        }

    }

    inline public static function useShader(shader:GLGraphics_GpuShader):Void {

        if (_boundProgram != shader.program) {
            _boundProgram = shader.program;
            GL.useProgram(shader.program);
        }

    }

    public static function deleteShader(shader:GLGraphics_GpuShader):Void {

        if (shader.vertShader != GLGraphics.NO_SHADER) {
            GL.deleteShader(shader.vertShader);
            shader.vertShader = GLGraphics.NO_SHADER;
        }

        if (shader.fragShader != GLGraphics.NO_SHADER) {
            GL.deleteShader(shader.fragShader);
            shader.fragShader = GLGraphics.NO_SHADER;
        }

        if (shader.program != GLGraphics.NO_SHADER) {
            GL.deleteShader(shader.fragShader);
            shader.fragShader = GLGraphics.NO_SHADER;
        }

    }

    public static function compileGLShader(type:Int, source:String):GLShader {

        inline function formatLog(log:String) {
            var items = log.split('\n');
            items = items.filter(function(s) { return StringTools.trim(s) != ''; });
            items = items.map(function(s) { return '\t\t' + StringTools.trim(s); });
            return items.join('\n');
        }

        var shader = GL.createShader(type);

        GL.shaderSource(shader, source);
        GL.compileShader(shader);

        var compileLog = GL.getShaderInfoLog(shader);
        var log = '';

        if (compileLog != null && compileLog.length > 0) {

            var isFrag = (type == GL.FRAGMENT_SHADER);
            var typeName = (isFrag) ? 'frag' : 'vert';

            log += '\n\t// start -- ($typeName) compile log --\n';
            log +=  formatLog(compileLog);
            log += '\n\t// end --\n';
        }

        if (GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 0) {

            Log.error('GL / Failed to compile shader:');
            Log.error(log.length == 0 ? formatLog(GL.getShaderInfoLog(shader)) : log);

            GL.deleteShader(shader);
            shader = NO_SHADER;
        }

        return shader;

    }

    inline public static function getUniformLocation(shader:GpuShader, name:String):GLUniformLocation {

        return GL.getUniformLocation(shader.program, name);

    }

    inline public static function setIntUniform(shader:GpuShader, location:GLUniformLocation, value:Int):Void {

        useShader(shader);
        GL.uniform1i(location, value);

    }

    inline public static function setFloatUniform(shader:GpuShader, location:GLUniformLocation, value:Float):Void {

        useShader(shader);
        GL.uniform1f(location, value);

    }

    inline public static function setFloatArrayUniform(shader:GpuShader, location:GLUniformLocation, value:Float32Array):Void {

        useShader(shader);
        GL.uniform1fv(location, value);

    }

    inline public static function setVector2Uniform(shader:GpuShader, location:GLUniformLocation, x:Float, y:Float):Void {

        useShader(shader);
        GL.uniform2f(location, x, y);

    }

    inline public static function setVector3Uniform(shader:GpuShader, location:GLUniformLocation, x:Float, y:Float, z:Float):Void {

        useShader(shader);
        GL.uniform3f(location, x, y, z);

    }

    inline public static function setVector4Uniform(shader:GpuShader, location:GLUniformLocation, x:Float, y:Float, z:Float, w:Float):Void {

        useShader(shader);
        GL.uniform4f(location, x, y, z, w);

    }

    inline public static function setColorUniform(shader:GpuShader, location:GLUniformLocation, r:Float, g:Float, b:Float, a:Float):Void {

        useShader(shader);
        GL.uniform4f(location, r, g, b, a);

    }

    inline public static function setMatrix4Uniform(shader:GpuShader, location:GLUniformLocation, value:Float32Array):Void {

        useShader(shader);
        GL.uniform4fv(location, value);

    }

    public static function setTexture2dUniform(shader:GpuShader, location:GLUniformLocation, slot:Int, texture:TextureId):Void {

        useShader(shader);
        GL.uniform1i(location, slot);
        setActiveTexture(slot);
        bindTexture2d(texture);

    }

    inline public static function setBlendFuncSeparate(srcRgb:BlendMode, dstRgb:BlendMode, srcAlpha:BlendMode, dstAlpha:BlendMode):Void {

        GL.blendFuncSeparate(
            srcRgb,
            dstRgb,
            srcAlpha,
            dstAlpha
        );

    }

}

@:allow(clay.opengl.GLGraphics)
class GLGraphics_RenderTarget {

    function new() {}

    /**
     * The final rendering destination of this texture
     * Needed for render target interface
     */
    public var framebuffer:GLFramebuffer;

    /**
     * The buffer used for offscreen rendering, which can include depth, stencil buffer...
     * Needed for render target interface
     */
    public var renderbuffer:GLRenderbuffer;

}

@:allow(clay.opengl.GLGraphics)
class GLGraphics_GpuShader {

    function new() {}

    public var vertShader:GLShader;

    public var fragShader:GLShader;

    public var program:GLProgram;

    public var textures:Array<String> = [];

}
