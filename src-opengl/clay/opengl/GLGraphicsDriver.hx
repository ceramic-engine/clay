package clay.opengl;

import clay.Types;
import clay.buffers.Float32Array;
import clay.buffers.Int32Array;
import clay.buffers.Uint8Array;
import clay.opengl.GL;

using clay.Extensions;

/**
 * OpenGL implementation of the cross-platform graphics driver interface.
 *
 * This class provides instance methods for GPU resource management including
 * textures, shaders, render targets, and framebuffer operations. It serves
 * as the OpenGL backend for Clay's graphics abstraction layer.
 *
 * The API is designed to be cross-platform, allowing other graphics backends
 * (D3D12, Metal, Vulkan) to implement equivalent functionality via spec.GraphicsDriver.
 *
 * Key features:
 * - Texture creation, binding, and management
 * - Shader compilation and uniform management
 * - Render target creation for off-screen rendering
 * - Framebuffer and renderbuffer management
 * - Blending and viewport configuration
 *
 * Access via Clay.app.graphics.
 */
class GLGraphicsDriver #if !completion implements clay.spec.GraphicsDriver #end {

    // ========================================================================
    // OpenGL Constants
    // ========================================================================

    inline static final DEPTH24_STENCIL8 = 0x88F0;

    inline static final DEPTH_COMPONENT24 = 33190;

    inline static final TEXTURE_2D_MULTISAMPLE = 0x9100;

    inline static final READ_FRAMEBUFFER = 36008;

    inline static final DRAW_FRAMEBUFFER = 36009;

    inline static final RGBA8 = 32856;

    inline static final COLOR = 6144;

    // ========================================================================
    // Sentinel Values (Cross-Platform API)
    // ========================================================================

    /**
     * Sentinel value representing no texture bound.
     */
    public var noTexture(get, never):TextureId;

    inline function get_noTexture():TextureId {
        return #if clay_web null #else 0 #end;
    }

    /**
     * Sentinel value representing the default framebuffer.
     */
    public var noFramebuffer(get, never):Framebuffer;

    inline function get_noFramebuffer():Framebuffer {
        return #if clay_web null #else 0 #end;
    }

    /**
     * Sentinel value representing the default renderbuffer.
     */
    public var noRenderbuffer(get, never):Renderbuffer;

    inline function get_noRenderbuffer():Renderbuffer {
        return #if clay_web null #else 0 #end;
    }

    /**
     * Sentinel value representing no shader handle.
     */
    public var noShader(get, never):ShaderHandle;

    inline function get_noShader():ShaderHandle {
        return #if clay_web null #else 0 #end;
    }

    /**
     * Sentinel value representing no program handle.
     */
    public var noProgram(get, never):ProgramHandle;

    inline function get_noProgram():ProgramHandle {
        return #if clay_web null #else 0 #end;
    }

    /**
     * Sentinel value representing an invalid uniform location.
     */
    public var noLocation(get, never):UniformLocation;

    inline function get_noLocation():UniformLocation {
        return #if clay_web null #else 0 #end;
    }

    /**
     * Sentinel value representing no buffer bound.
     */
    public var noBuffer(get, never):BufferHandle;

    inline function get_noBuffer():BufferHandle {
        return #if clay_web null #else 0 #end;
    }

    // ========================================================================
    // Instance State
    // ========================================================================

    var _boundTexture2D:Array<TextureId> = [];

    var _boundProgram:GLProgram;

    var _activeTextureSlot:Int = -1;

    var _boundFramebuffer:GLFramebuffer;

    var _boundRenderbuffer:GLRenderbuffer;

    var _didFetchDefaultBuffers:Bool = false;

    var _defaultFramebuffer:GLFramebuffer;

    var _defaultRenderbuffer:GLRenderbuffer;

    final _clearBufferForBlitValues:Float32Array;

    // ========================================================================
    // Constructor
    // ========================================================================

    /**
     * Creates a new OpenGL graphics driver instance.
     */
    public function new() {
        _boundProgram = noProgram;
        _boundFramebuffer = noFramebuffer;
        _boundRenderbuffer = noRenderbuffer;
        _defaultFramebuffer = noFramebuffer;
        _defaultRenderbuffer = noRenderbuffer;
        _clearBufferForBlitValues = Float32Array.fromArray([0.0, 0.0, 0.0, 1.0]);
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    /**
     * Initializes the graphics driver after the graphics context is ready.
     *
     * This must be called once after the window and graphics context are created.
     * Fetches default framebuffer and renderbuffer bindings from the platform.
     */
    public function setup():Void {
        _defaultFramebuffer = GL.getParameter(GL.FRAMEBUFFER_BINDING);
        _defaultRenderbuffer = GL.getParameter(GL.RENDERBUFFER_BINDING);
        _didFetchDefaultBuffers = true;
    }

    // ========================================================================
    // GPU Capabilities (Cross-Platform API)
    // ========================================================================

    /**
     * Returns the maximum texture size supported by the GPU.
     *
     * @return Maximum texture dimension in pixels
     */
    public function getMaxTextureSize():Int {
        var size = GL.getParameter(GL.MAX_TEXTURE_SIZE);
        // It seems that on some devices value may be below 0
        // In that case, just use 4096 as safe value
        if (size <= 0) {
            size = 4096;
        }
        return size;
    }

    /**
     * Returns the maximum number of texture units available.
     *
     * @return Maximum number of texture units (capped at 32)
     */
    public function getMaxTextureUnits():Int {
        var maxUnits = GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS);
        return Std.int(Math.min(32, maxUnits));
    }

    /**
     * Tests the maximum number of if-statements supported in fragment shaders.
     *
     * This is used for multi-texture batching optimization, which requires
     * conditional texture sampling based on texture ID per vertex.
     *
     * @param maxIfs Starting maximum to test (halves on failure until working)
     * @return Maximum number of if-statements supported
     */
    public function testShaderCompilationLimit(maxIfs:Int = 32):Int {
        var fragTpl = StringTools.trim("
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif
varying float test;
void main() {
    {{CONDITIONS}}
    gl_FragColor = vec4(0.0);
}
");
        var shader = GL.createShader(GL.FRAGMENT_SHADER);
        var result = 0;

        while (maxIfs > 0) {
            var conditions = _generateIfStatements(maxIfs);
            var frag = StringTools.replace(fragTpl, '{{CONDITIONS}}', conditions);

            GL.shaderSource(shader, frag);
            GL.compileShader(shader);

            if (GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 0) {
                // That's too many ifs apparently
                maxIfs = Std.int(maxIfs / 2);
            } else {
                // It works!
                result = maxIfs;
                break;
            }
        }

        GL.deleteShader(shader);
        return result;
    }

    /**
     * Generates a series of if-else statements for shader compilation testing.
     *
     * @param maxIfs Number of if-statements to generate
     * @return GLSL code with chained if-else statements
     */
    function _generateIfStatements(maxIfs:Int):String {
        var result = new StringBuf();

        for (i in 0...maxIfs) {
            if (i > 0) {
                result.add('\nelse ');
            }

            if (i < maxIfs - 1) {
                result.add('if (test == ');
                result.add(i);
                result.add('.0) {}');
            }
        }

        return result.toString();
    }

    /**
     * Loads platform-specific graphics extensions.
     *
     * On WebGL, this loads extensions like OES_standard_derivatives
     * that provide additional shader functionality.
     */
    public function loadExtensions():Void {
        #if web
        var ext = GL.gl.getExtension('OES_standard_derivatives');
        #end
    }

    /**
     * Reads pixels from the current framebuffer.
     *
     * The pixels are read in RGBA format with unsigned bytes (0-255).
     * The buffer must be large enough to hold width * height * 4 bytes.
     *
     * @param x X position to start reading
     * @param y Y position to start reading
     * @param width Width of the rectangle to read
     * @param height Height of the rectangle to read
     * @param pixels Buffer to store RGBA pixel data
     */
    public function readPixels(x:Int, y:Int, width:Int, height:Int, pixels:Uint8Array):Void {
        GL.readPixels(x, y, width, height, GL.RGBA, GL.UNSIGNED_BYTE, pixels);
    }

    // ========================================================================
    // Rendering State
    // ========================================================================

    /**
     * Clears the current render buffer.
     *
     * @param r Red component of clear color (0.0 to 1.0)
     * @param g Green component of clear color (0.0 to 1.0)
     * @param b Blue component of clear color (0.0 to 1.0)
     * @param a Alpha component of clear color (0.0 to 1.0)
     * @param clearDepth Whether to also clear the depth buffer (default: true)
     */
    public function clear(r:Float, g:Float, b:Float, a:Float, clearDepth:Bool = true):Void {
        GL.clearColor(r, g, b, a);

        if (clearDepth && Clay.app.config.render.depth > 0) {
            GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
            GL.clearDepth(1.0);
        } else {
            GL.clear(GL.COLOR_BUFFER_BIT);
        }
    }

    /**
     * Sets the viewport dimensions.
     *
     * @param x Left edge of viewport
     * @param y Bottom edge of viewport
     * @param width Viewport width in pixels
     * @param height Viewport height in pixels
     */
    public inline function setViewport(x:Int, y:Int, width:Int, height:Int):Void {
        GL.viewport(x, y, width, height);
    }

    /**
     * Enables alpha blending for subsequent draw operations.
     */
    public inline function enableBlending():Void {
        GL.enable(GL.BLEND);
    }

    /**
     * Disables alpha blending for subsequent draw operations.
     */
    public inline function disableBlending():Void {
        GL.disable(GL.BLEND);
    }

    /**
     * Sets separate blend functions for RGB and alpha channels.
     *
     * @param srcRgb Source blend factor for RGB channels
     * @param dstRgb Destination blend factor for RGB channels
     * @param srcAlpha Source blend factor for alpha channel
     * @param dstAlpha Destination blend factor for alpha channel
     */
    public inline function setBlendFuncSeparate(srcRgb:BlendMode, dstRgb:BlendMode, srcAlpha:BlendMode, dstAlpha:BlendMode):Void {
        GL.blendFuncSeparate(
            srcRgb,
            dstRgb,
            srcAlpha,
            dstAlpha
        );
    }

    // ========================================================================
    // Texture Management
    // ========================================================================

    /**
     * Creates a new texture and returns its identifier.
     *
     * @return New texture identifier
     */
    public inline function createTextureId():TextureId {
        return GL.createTexture();
    }

    /**
     * Deletes a texture from the GPU.
     *
     * @param textureId Texture identifier to delete
     */
    public inline function deleteTexture(textureId:TextureId):Void {
        GL.deleteTexture(textureId);

        for (i in 0..._boundTexture2D.length) {
            if (_boundTexture2D.unsafeGet(i) == textureId) {
                _boundTexture2D.unsafeSet(i, noTexture);
            }
        }
    }

    /**
     * Sets the active texture slot for subsequent texture operations.
     *
     * @param slot Texture slot index (0-based)
     */
    public inline function setActiveTexture(slot:Int):Void {
        if (_activeTextureSlot != slot) {
            _activeTextureSlot = slot;
            while (_boundTexture2D.length <= _activeTextureSlot)
                _boundTexture2D.push(noTexture);
            GL.activeTexture(GL.TEXTURE0 + slot);
        }
    }

    /**
     * Binds a 2D texture to the current texture slot.
     *
     * @param textureId Texture identifier to bind, or noTexture to unbind
     */
    public inline function bindTexture2d(textureId:TextureId):Void {
        if (_boundTexture2D.unsafeGet(_activeTextureSlot) != textureId) {
            _boundTexture2D.unsafeSet(_activeTextureSlot, textureId);
            GL.bindTexture(GL.TEXTURE_2D, textureId);
        }
    }

    /**
     * Returns the maximum texture size supported by the GPU.
     *
     * @return Maximum texture dimension in pixels
     */
    public inline function maxTextureSize():Int {
        var size = GL.getParameter(GL.MAX_TEXTURE_SIZE);
        // It seems that on some devices value may be below 0
        // In that case, just use 4096 as safe value
        if (size <= 0) {
            size = 4096;
        }
        return size;
    }

    /**
     * Checks if premultiplied textures require pixel preprocessing.
     *
     * @return True if preprocessing is needed, false if handled by GL
     */
    public inline function needsPreprocessedPremultipliedAlpha():Bool {
        #if (web && clay_webgl_unpack_premultiply_alpha)
        return false;
        #else
        return true;
        #end
    }

    /**
     * Submits 2D texture pixels to the GPU.
     *
     * @param level Mipmap level (0 = base image)
     * @param format Texture format (RGB or RGBA)
     * @param width Texture width in pixels
     * @param height Texture height in pixels
     * @param dataType Data type of pixel data (UNSIGNED_BYTE)
     * @param pixels Pixel data buffer
     * @param premultipliedAlpha Whether pixels use premultiplied alpha
     */
    public inline function submitTexture2dPixels(level:Int, format:TextureFormat, width:Int, height:Int,
            dataType:TextureDataType, pixels:Uint8Array, premultipliedAlpha:Bool):Void {
        #if web
        GL.pixelStorei(GL.UNPACK_PREMULTIPLY_ALPHA_WEBGL, premultipliedAlpha ? 1 : 0);
        #end

        GL.texImage2D(GL.TEXTURE_2D, level, format, width, height, 0, format, dataType, pixels);
    }

    /**
     * Submits compressed 2D texture pixels to the GPU.
     *
     * @param level Mipmap level (0 = base image)
     * @param format Compressed texture format
     * @param width Texture width in pixels
     * @param height Texture height in pixels
     * @param pixels Compressed pixel data buffer
     * @param premultipliedAlpha Whether pixels use premultiplied alpha
     */
    public inline function submitCompressedTexture2dPixels(level:Int, format:TextureFormat, width:Int, height:Int,
            pixels:Uint8Array, premultipliedAlpha:Bool):Void {
        #if (web && clay_webgl_unpack_premultiply_alpha)
        GL.pixelStorei(GL.UNPACK_PREMULTIPLY_ALPHA_WEBGL, premultipliedAlpha ? 1 : 0);
        #end

        GL.compressedTexImage2D(GL.TEXTURE_2D, level, format, width, height, 0, pixels);
    }

    /**
     * Fetches 2D texture pixels from the GPU.
     *
     * @param into Buffer to store pixel data (must be at least w * h * 4 bytes)
     * @param x X position of texture rectangle to fetch
     * @param y Y position of texture rectangle to fetch
     * @param w Width of texture rectangle to fetch
     * @param h Height of texture rectangle to fetch
     */
    public function fetchTexture2dPixels(into:Uint8Array, x:Int, y:Int, w:Int, h:Int):Void {
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

        GL.bindFramebuffer(GL.FRAMEBUFFER, noFramebuffer);
        GL.deleteFramebuffer(fb);
    }

    /**
     * Sets the minification filter for 2D textures.
     *
     * @param minFilter Filter mode (NEAREST, LINEAR, or mipmap variants)
     */
    public inline function setTexture2dMinFilter(minFilter:TextureFilter):Void {
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, minFilter);
    }

    /**
     * Sets the magnification filter for 2D textures.
     *
     * @param magFilter Filter mode (NEAREST or LINEAR)
     */
    public inline function setTexture2dMagFilter(magFilter:TextureFilter):Void {
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, magFilter);
    }

    /**
     * Sets the horizontal (S) texture wrap mode.
     *
     * @param wrapS Wrap mode (CLAMP_TO_EDGE, REPEAT, or MIRRORED_REPEAT)
     */
    public inline function setTexture2dWrapS(wrapS:TextureWrap):Void {
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrapS);
    }

    /**
     * Sets the vertical (T) texture wrap mode.
     *
     * @param wrapT Wrap mode (CLAMP_TO_EDGE, REPEAT, or MIRRORED_REPEAT)
     */
    public inline function setTexture2dWrapT(wrapT:TextureWrap):Void {
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrapT);
    }

    // ========================================================================
    // Framebuffer/Renderbuffer Management
    // ========================================================================

    /**
     * Creates a new framebuffer object.
     *
     * @return Created framebuffer
     */
    public inline function createFramebuffer():Framebuffer {
        return GL.createFramebuffer();
    }

    /**
     * Binds a framebuffer for rendering.
     *
     * @param framebuffer Framebuffer to bind, or noFramebuffer for default
     */
    public function bindFramebuffer(framebuffer:Framebuffer):Void {
        if (_boundFramebuffer != framebuffer) {
            _boundFramebuffer = framebuffer;

            if (framebuffer == noFramebuffer)
                framebuffer = _defaultFramebuffer;

            GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer);
        }
    }

    /**
     * Creates a new renderbuffer object.
     *
     * @return Created renderbuffer
     */
    public inline function createRenderbuffer():Renderbuffer {
        return GL.createRenderbuffer();
    }

    /**
     * Binds a renderbuffer.
     *
     * @param renderbuffer Renderbuffer to bind, or noRenderbuffer for default
     */
    public function bindRenderbuffer(renderbuffer:Renderbuffer):Void {
        if (_boundRenderbuffer != renderbuffer) {
            _boundRenderbuffer = renderbuffer;

            if (renderbuffer == noRenderbuffer)
                renderbuffer = _defaultRenderbuffer;

            GL.bindRenderbuffer(GL.RENDERBUFFER, renderbuffer);
        }
    }

    // ========================================================================
    // Render Target Management
    // ========================================================================

    /**
     * Creates a render target for off-screen rendering.
     *
     * @param textureId Texture to render into
     * @param width Render target width in pixels
     * @param height Render target height in pixels
     * @param depth Whether to include a depth buffer
     * @param stencil Whether to include a stencil buffer
     * @param antialiasing MSAA sample count (0 or 1 for none)
     * @param level Mipmap level (0 = base)
     * @param format Texture format
     * @param dataType Data type of texture
     * @return Created render target
     */
    public function createRenderTarget(textureId:TextureId, width:Int, height:Int, depth:Bool, stencil:Bool,
            antialiasing:Int, level:Int, format:TextureFormat, dataType:TextureDataType):RenderTarget {
        var renderTarget = new GLGraphicsDriver_RenderTarget();

        // Create actual texture gpu storage
        GL.texImage2D(GL.TEXTURE_2D, level, format, width, height, 0, format, dataType, null);

        // Create the framebuffer
        renderTarget.framebuffer = createFramebuffer();

        // Create the renderbuffer
        renderTarget.renderbuffer = createRenderbuffer();

        if (antialiasing > 1) {
            // Create buffers for multisampling, if antialiasing is enabled
            renderTarget.msResolveFramebuffer = createFramebuffer();
            renderTarget.msResolveColorRenderbuffer = createRenderbuffer();
            if (depth || stencil)
                renderTarget.msDepthStencilRenderbuffer = createRenderbuffer();
            else
                renderTarget.msDepthStencilRenderbuffer = noRenderbuffer;
        } else {
            renderTarget.msResolveFramebuffer = noFramebuffer;
            renderTarget.msResolveColorRenderbuffer = noRenderbuffer;
            renderTarget.msDepthStencilRenderbuffer = noRenderbuffer;
        }

        // Configure buffers storage
        configureRenderTargetBuffersStorage(renderTarget, textureId, width, height, depth, stencil, antialiasing);

        return renderTarget;
    }

    /**
     * Deletes a render target from the GPU.
     *
     * @param renderTarget Render target to delete
     */
    public function deleteRenderTarget(renderTarget:RenderTarget):Void {
        var rt:GLGraphicsDriver_RenderTarget = cast renderTarget;

        if (rt.framebuffer != noFramebuffer) {
            if (_boundFramebuffer == rt.framebuffer) {
                _boundFramebuffer = noFramebuffer;
            }
            GL.deleteFramebuffer(rt.framebuffer);
            rt.framebuffer = noFramebuffer;
        }

        if (rt.renderbuffer != noRenderbuffer) {
            if (_boundRenderbuffer == rt.renderbuffer) {
                _boundRenderbuffer = noRenderbuffer;
            }
            GL.deleteRenderbuffer(rt.renderbuffer);
            rt.renderbuffer = noRenderbuffer;
        }

        if (rt.msDepthStencilRenderbuffer != noRenderbuffer) {
            if (_boundRenderbuffer == rt.msDepthStencilRenderbuffer) {
                _boundRenderbuffer = noRenderbuffer;
            }
            GL.deleteRenderbuffer(rt.msDepthStencilRenderbuffer);
            rt.msDepthStencilRenderbuffer = noRenderbuffer;
        }

        if (rt.msResolveColorRenderbuffer != noRenderbuffer) {
            if (_boundRenderbuffer == rt.msResolveColorRenderbuffer) {
                _boundRenderbuffer = noRenderbuffer;
            }
            GL.deleteRenderbuffer(rt.msResolveColorRenderbuffer);
            rt.msResolveColorRenderbuffer = noRenderbuffer;
        }

        if (rt.msResolveFramebuffer != noFramebuffer) {
            if (_boundFramebuffer == rt.msResolveFramebuffer) {
                _boundFramebuffer = noFramebuffer;
            }
            GL.deleteFramebuffer(rt.msResolveFramebuffer);
            rt.msResolveFramebuffer = noFramebuffer;
        }
    }

    /**
     * Sets the render target for subsequent draw operations.
     *
     * @param renderTarget Render target to draw into, or null for main framebuffer
     */
    public inline function setRenderTarget(renderTarget:RenderTarget):Void {
        if (renderTarget != null) {
            var rt:GLGraphicsDriver_RenderTarget = cast renderTarget;
            bindFramebuffer(rt.framebuffer);
            bindRenderbuffer(rt.renderbuffer);
        } else {
            bindFramebuffer(noFramebuffer);
            bindRenderbuffer(noRenderbuffer);
        }
    }

    /**
     * Configures storage for render target buffers.
     *
     * Used when resizing a render target's underlying buffers.
     *
     * @param renderTarget Render target to configure
     * @param textureId Texture associated with the render target
     * @param width New width in pixels
     * @param height New height in pixels
     * @param depth Whether to include depth buffer
     * @param stencil Whether to include stencil buffer
     * @param antialiasing MSAA sample count
     */
    public function configureRenderTargetBuffersStorage(renderTarget:RenderTarget, textureId:TextureId,
            width:Int, height:Int, depth:Bool, stencil:Bool, antialiasing:Int):Void {
        var rt:GLGraphicsDriver_RenderTarget = cast renderTarget;

        if (antialiasing > 1) {
            // Setup multisample color RBO
            bindRenderbuffer(rt.renderbuffer);
            GL.renderbufferStorageMultisample(GL.RENDERBUFFER, antialiasing, RGBA8, width, height);

            // Setup multisample depth/stencil RBO
            if (depth || stencil) {
                bindRenderbuffer(rt.msDepthStencilRenderbuffer);
                if (stencil) {
                    GL.renderbufferStorageMultisample(GL.RENDERBUFFER, antialiasing, DEPTH24_STENCIL8, width, height);
                } else {
                    GL.renderbufferStorageMultisample(GL.RENDERBUFFER, antialiasing, GL.DEPTH_COMPONENT16, width, height);
                }
            }

            // Setup multisample FBO
            bindFramebuffer(rt.framebuffer);
            GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.RENDERBUFFER, rt.renderbuffer);
            if (depth || stencil) {
                if (stencil) {
                    GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_STENCIL_ATTACHMENT, GL.RENDERBUFFER, rt.msDepthStencilRenderbuffer);
                } else {
                    GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, rt.msDepthStencilRenderbuffer);
                }
            }

            // Setup resolve color RBO
            bindRenderbuffer(rt.msResolveColorRenderbuffer);
            GL.renderbufferStorage(GL.RENDERBUFFER, RGBA8, width, height);

            // Setup resolve FBO
            bindFramebuffer(rt.msResolveFramebuffer);
            GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, textureId, 0);
        } else {
            // Setup RBO
            bindRenderbuffer(rt.renderbuffer);
            if (stencil) {
                #if (ios || tvos || android || gles_angle)
                GL.renderbufferStorage(GL.RENDERBUFFER, DEPTH24_STENCIL8, width, height);
                #else
                GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_STENCIL, width, height);
                #end
            } else if (depth) {
                #if (web || ios || tvos || android || gles_angle)
                GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, width, height);
                #else
                GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT, width, height);
                #end
            } else {
                GL.renderbufferStorage(GL.RENDERBUFFER, GL.RGBA, width, height);
            }

            // Setup FBO
            bindFramebuffer(rt.framebuffer);
            GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, textureId, 0);
            if (depth || stencil) {
                if (stencil) {
                    GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_STENCIL_ATTACHMENT, GL.RENDERBUFFER, rt.renderbuffer);
                } else {
                    GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, rt.renderbuffer);
                }
            }
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
            case 36059:
                throw("Incomplete framebuffer: FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER");
            case 36060:
                throw("Incomplete framebuffer: FRAMEBUFFER_INCOMPLETE_READ_BUFFER");
            case 36182:
                throw("Incomplete framebuffer: FRAMEBUFFER_INCOMPLETE_MULTISAMPLE");
            default:
                throw("Incomplete framebuffer: " + status);
        }

        // Unbind buffers
        bindFramebuffer(noFramebuffer);
        bindRenderbuffer(noRenderbuffer);
    }

    /**
     * Resolves MSAA render target buffers to the texture.
     *
     * Called when switching away from an antialiased render target
     * to blit the multisampled content to the texture.
     *
     * @param renderTarget Render target to resolve
     * @param width Width of the render target
     * @param height Height of the render target
     */
    public function blitRenderTargetBuffers(renderTarget:RenderTarget, width:Int, height:Int):Void {
        var rt:GLGraphicsDriver_RenderTarget = cast renderTarget;

        // No Multisample texture 2d in WebGL 2
        // Instead we blit framebuffers, which works on all gl targets so far.
        GL.bindFramebuffer(READ_FRAMEBUFFER, rt.framebuffer);
        GL.bindFramebuffer(DRAW_FRAMEBUFFER, rt.msResolveFramebuffer);
        GL.clearBufferfv(COLOR, 0, _clearBufferForBlitValues);
        GL.blitFramebuffer(
            0, 0, width, height,
            0, 0, width, height,
            GL.COLOR_BUFFER_BIT, GL.NEAREST
        );
        GL.bindFramebuffer(READ_FRAMEBUFFER, noFramebuffer);
        GL.bindFramebuffer(DRAW_FRAMEBUFFER, noFramebuffer);
    }

    // ========================================================================
    // Shader Management
    // ========================================================================

    /**
     * Creates and compiles a shader program.
     *
     * Automatically patches GLSL version for platform compatibility:
     * - Desktop GL (non-ANGLE): converts `#version 300 es` to `#version 330`
     * - Mobile/WebGL (GLES/ANGLE): keeps `#version 300 es`
     *
     * @param vertSource Vertex shader source code
     * @param fragSource Fragment shader source code
     * @param attributes Optional array of attribute names in binding order
     * @param textures Optional array of texture uniform names in slot order
     * @return Compiled shader, or null on failure
     */
    public function createShader(vertSource:String, fragSource:String, ?attributes:Array<String>, ?textures:Array<String>):GpuShader {
        if (vertSource == null)
            throw 'Cannot create shader: vertSource is null!';
        if (fragSource == null)
            throw 'Cannot create shader: fragSource is null!';

        // Apply GLSL version patching for platform compatibility
        vertSource = patchGlslVersion(vertSource);
        fragSource = patchGlslVersion(fragSource);

        var shader = new GLGraphicsDriver_GpuShader();

        shader.vertShader = compileGLShader(GL.VERTEX_SHADER, vertSource);
        if (shader.vertShader == noShader) {
            deleteShader(shader);
            return null;
        }

        shader.fragShader = compileGLShader(GL.FRAGMENT_SHADER, fragSource);
        if (shader.fragShader == noShader) {
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

    /**
     * Patches GLSL version directive for platform compatibility.
     *
     * Shade compiler outputs GLES 3.0 syntax (`#version 300 es`).
     * Desktop GL (non-ANGLE) requires `#version 330` instead.
     *
     * @param source Shader source code
     * @return Patched source code
     */
    function patchGlslVersion(source:String):String {
        #if !(ios || android || tvos || web || gles_angle)
        // Desktop GL needs version 330 instead of 300 es
        if (source.substr(0, 15) == '#version 300 es') {
            return '#version 330' + source.substr(15);
        }
        #end
        return source;
    }

    /**
     * Deletes a shader program from the GPU.
     *
     * @param shader Shader program to delete
     */
    public function deleteShader(shader:GpuShader):Void {
        var s:GLGraphicsDriver_GpuShader = cast shader;

        if (_boundProgram == s.program) {
            _boundProgram = noProgram;
        }

        if (s.vertShader != noShader) {
            GL.deleteShader(s.vertShader);
            s.vertShader = noShader;
        }

        if (s.fragShader != noShader) {
            GL.deleteShader(s.fragShader);
            s.fragShader = noShader;
        }

        if (s.program != noProgram) {
            GL.deleteProgram(s.program);
            s.program = noProgram;
        }
    }

    /**
     * Activates a shader program for subsequent draw operations.
     *
     * @param shader Shader program to use
     */
    public inline function useShader(shader:GpuShader):Void {
        var s:GLGraphicsDriver_GpuShader = cast shader;
        if (_boundProgram != s.program) {
            _boundProgram = s.program;
            GL.useProgram(s.program);
        }
    }

    /**
     * Synchronizes projectionMatrix and modelViewMatrix
     * with the given shader, as this is needed on some graphics backend.
     * @param shader Shader program to synchronize
     */
    public inline function synchronizeShaderMatrices(shader:GpuShader):Void {
        // Update this shader the the latest known projection and modelView matrices
        setMatrix4Uniform(
            shader,
            getUniformLocation(shader, 'projectionMatrix'),
            projectionMatrix
        );
        setMatrix4Uniform(
            shader,
            getUniformLocation(shader, 'modelViewMatrix'),
            modelViewMatrix
        );
    }

    /**
     * Gets the location of a uniform variable in a shader.
     *
     * @param shader Shader program
     * @param name Uniform variable name
     * @return Uniform location, or noLocation if not found
     */
    public inline function getUniformLocation(shader:GpuShader, name:String):UniformLocation {
        var s:GLGraphicsDriver_GpuShader = cast shader;
        return GL.getUniformLocation(s.program, name);
    }

    /**
     * Sets an integer uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Integer value
     */
    public inline function setIntUniform(shader:GpuShader, location:UniformLocation, value:Int):Void {
        useShader(shader);
        GL.uniform1i(location, value);
    }

    /**
     * Sets an integer array uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Integer array
     */
    public inline function setIntArrayUniform(shader:GpuShader, location:UniformLocation, value:Int32Array):Void {
        useShader(shader);
        GL.uniform1iv(location, value);
    }

    /**
     * Sets a float uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Float value
     */
    public inline function setFloatUniform(shader:GpuShader, location:UniformLocation, value:Float):Void {
        useShader(shader);
        GL.uniform1f(location, value);
    }

    /**
     * Sets a float array uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Float array
     */
    public inline function setFloatArrayUniform(shader:GpuShader, location:UniformLocation, value:Float32Array):Void {
        useShader(shader);
        GL.uniform1fv(location, value);
    }

    /**
     * Sets a 2D vector uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param x X component
     * @param y Y component
     */
    public inline function setVector2Uniform(shader:GpuShader, location:UniformLocation, x:Float, y:Float):Void {
        useShader(shader);
        GL.uniform2f(location, x, y);
    }

    /**
     * Sets a 3D vector uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param x X component
     * @param y Y component
     * @param z Z component
     */
    public inline function setVector3Uniform(shader:GpuShader, location:UniformLocation, x:Float, y:Float, z:Float):Void {
        useShader(shader);
        GL.uniform3f(location, x, y, z);
    }

    /**
     * Sets a 4D vector uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param x X component
     * @param y Y component
     * @param z Z component
     * @param w W component
     */
    public inline function setVector4Uniform(shader:GpuShader, location:UniformLocation, x:Float, y:Float, z:Float, w:Float):Void {
        useShader(shader);
        GL.uniform4f(location, x, y, z, w);
    }

    /**
     * Sets a 2x2 matrix uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Matrix as Float32Array (4 elements, column-major)
     */
    public inline function setMatrix2Uniform(shader:GpuShader, location:UniformLocation, value:Float32Array):Void {
        useShader(shader);
        GL.uniformMatrix2fv(location, false, value);
    }

    /**
     * Sets a 3x3 matrix uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Matrix as Float32Array (9 elements, column-major)
     */
    public inline function setMatrix3Uniform(shader:GpuShader, location:UniformLocation, value:Float32Array):Void {
        useShader(shader);
        GL.uniformMatrix3fv(location, false, value);
    }

    /**
     * Sets a 4x4 matrix uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Matrix as Float32Array (16 elements, column-major)
     */
    public inline function setMatrix4Uniform(shader:GpuShader, location:UniformLocation, value:Float32Array):Void {
        useShader(shader);
        GL.uniformMatrix4fv(location, false, value);
    }

    /**
     * Sets a texture sampler uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param slot Texture slot index
     * @param texture Texture identifier to bind
     */
    public function setTexture2dUniform(shader:GpuShader, location:UniformLocation, slot:Int, texture:TextureId):Void {
        useShader(shader);
        GL.uniform1i(location, slot);
        setActiveTexture(slot);
        bindTexture2d(texture);
    }

    // ========================================================================
    // OpenGL-Specific Helpers (Internal)
    // ========================================================================

    var projectionMatrix = clay.buffers.Float32Array.fromArray([
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    ]);

    var modelViewMatrix = clay.buffers.Float32Array.fromArray([
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    ]);

    /**
     * Links vertex and fragment shaders into a program.
     *
     * @param shader Shader object with compiled vert/frag shaders
     * @param attributes Optional array of attribute names in binding order
     * @return True if linking succeeded, false otherwise
     */
    function linkShader(shader:GLGraphicsDriver_GpuShader, ?attributes:Array<String>):Bool {
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

    /**
     * Configures texture slot uniform bindings for a shader.
     *
     * @param shader Shader to configure
     * @param textures Array of texture uniform names in slot order
     */
    function configureShaderTextureSlots(shader:GLGraphicsDriver_GpuShader, textures:Array<String>):Void {
        useShader(shader);

        for (i in 0...textures.length) {
            var texture = textures.unsafeGet(i);
            var attr = GL.getUniformLocation(shader.program, texture);
            if (attr != noLocation) {
                GL.uniform1i(attr, i);
                shader.textures[i] = texture;
            }
        }
    }

    /**
     * Compiles a single GL shader (vertex or fragment).
     *
     * @param type GL.VERTEX_SHADER or GL.FRAGMENT_SHADER
     * @param source GLSL source code
     * @return Compiled shader, or noShader on failure
     */
    function compileGLShader(type:Int, source:String):GLShader {
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
            shader = noShader;
        }

        return shader;
    }

    // ========================================================================
    // Error Checking
    // ========================================================================

    /**
     * Checks for and throws on any pending graphics errors.
     *
     * Useful for debugging graphics operations.
     */
    public inline function ensureNoError():Void {
        var error = GL.getError();
        if (error != GL.NO_ERROR) {
            throw 'Failed with GL error: $error';
        }
    }
}

/**
 * OpenGL render target implementation.
 *
 * Stores framebuffer and renderbuffer handles for off-screen rendering,
 * including MSAA support with resolve buffers.
 */
@:allow(clay.opengl.GLGraphicsDriver)
class GLGraphicsDriver_RenderTarget {

    function new() {}

    /**
     * The final rendering destination of this texture.
     */
    public var framebuffer:GLFramebuffer;

    /**
     * The buffer used for offscreen rendering (depth, stencil, or color).
     */
    public var renderbuffer:GLRenderbuffer;

    /**
     * Additional framebuffer used when multisampling is enabled.
     */
    public var msResolveFramebuffer:GLFramebuffer;

    /**
     * Additional renderbuffer used when multisampling is enabled.
     */
    public var msResolveColorRenderbuffer:GLRenderbuffer;

    /**
     * Additional renderbuffer for depth/stencil when multisampling is enabled.
     */
    public var msDepthStencilRenderbuffer:GLRenderbuffer;
}

/**
 * OpenGL shader program implementation.
 *
 * Stores compiled vertex/fragment shaders and the linked program.
 */
@:allow(clay.opengl.GLGraphicsDriver)
class GLGraphicsDriver_GpuShader {

    function new() {}

    /**
     * Compiled vertex shader handle.
     */
    public var vertShader:GLShader;

    /**
     * Compiled fragment shader handle.
     */
    public var fragShader:GLShader;

    /**
     * Linked shader program handle.
     */
    public var program:GLProgram;

    /**
     * Array of texture uniform names by slot index.
     */
    public var textures:Array<String> = [];
}
