package clay.spec;

import clay.Types;
import clay.buffers.Float32Array;
import clay.buffers.Int32Array;
import clay.buffers.Uint8Array;

/**
 * Interface for graphics driver implementations.
 *
 * Provides a unified API for GPU resource management across different graphics backends
 * (OpenGL, D3D12, Metal, Vulkan). Each backend implements this interface with
 * platform-specific optimizations.
 *
 * The graphics driver manages:
 * - Texture creation, binding, and management
 * - Shader compilation and uniform management
 * - Render target creation for off-screen rendering
 * - Framebuffer and renderbuffer management
 * - Blending and viewport configuration
 *
 * Typical usage:
 * - Access via Clay.app.graphics
 * - Call setup() after graphics context is initialized
 * - Use methods to manage GPU resources
 */
interface GraphicsDriver {

    // ========================================================================
    // Initialization
    // ========================================================================

    /**
     * Initializes the graphics driver after the graphics context is ready.
     *
     * This must be called once after the window and graphics context are created.
     * Fetches default framebuffer and renderbuffer bindings from the platform.
     */
    function setup():Void;

    // ========================================================================
    // GPU Capabilities (Cross-Platform API)
    // ========================================================================

    /**
     * Returns the maximum texture size supported by the GPU.
     *
     * @return Maximum texture dimension in pixels
     */
    function getMaxTextureSize():Int;

    /**
     * Returns the maximum number of texture units available.
     *
     * @return Maximum number of texture units (capped at 32)
     */
    function getMaxTextureUnits():Int;

    /**
     * Tests the maximum number of if-statements supported in fragment shaders.
     *
     * This is used for multi-texture batching optimization, which requires
     * conditional texture sampling based on texture ID per vertex.
     *
     * @param maxIfs Starting maximum to test (halves on failure until working)
     * @return Maximum number of if-statements supported
     */
    function testShaderCompilationLimit(maxIfs:Int = 32):Int;

    /**
     * Loads platform-specific graphics extensions.
     *
     * On WebGL, this loads extensions like OES_standard_derivatives
     * that provide additional shader functionality.
     */
    function loadExtensions():Void;

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
    function readPixels(x:Int, y:Int, width:Int, height:Int, pixels:Uint8Array):Void;

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
    function clear(r:Float, g:Float, b:Float, a:Float, clearDepth:Bool = true):Void;

    /**
     * Sets the viewport dimensions.
     *
     * @param x Left edge of viewport
     * @param y Bottom edge of viewport
     * @param width Viewport width in pixels
     * @param height Viewport height in pixels
     */
    function setViewport(x:Int, y:Int, width:Int, height:Int):Void;

    /**
     * Enables alpha blending for subsequent draw operations.
     */
    function enableBlending():Void;

    /**
     * Disables alpha blending for subsequent draw operations.
     */
    function disableBlending():Void;

    /**
     * Sets separate blend functions for RGB and alpha channels.
     *
     * @param srcRgb Source blend factor for RGB channels
     * @param dstRgb Destination blend factor for RGB channels
     * @param srcAlpha Source blend factor for alpha channel
     * @param dstAlpha Destination blend factor for alpha channel
     */
    function setBlendFuncSeparate(srcRgb:BlendMode, dstRgb:BlendMode, srcAlpha:BlendMode, dstAlpha:BlendMode):Void;

    // ========================================================================
    // Texture Management
    // ========================================================================

    /**
     * Creates a new texture and returns its identifier.
     *
     * @return New texture identifier
     */
    function createTextureId():TextureId;

    /**
     * Deletes a texture from the GPU.
     *
     * @param textureId Texture identifier to delete
     */
    function deleteTexture(textureId:TextureId):Void;

    /**
     * Sets the active texture slot for subsequent texture operations.
     *
     * @param slot Texture slot index (0-based)
     */
    function setActiveTexture(slot:Int):Void;

    /**
     * Binds a 2D texture to the current texture slot.
     *
     * @param textureId Texture identifier to bind, or noTexture to unbind
     */
    function bindTexture2d(textureId:TextureId):Void;

    /**
     * Returns the maximum texture size supported by the GPU.
     *
     * @return Maximum texture dimension in pixels
     */
    function maxTextureSize():Int;

    /**
     * Checks if premultiplied textures require pixel preprocessing.
     *
     * @return True if preprocessing is needed, false if handled by GL
     */
    function needsPreprocessedPremultipliedAlpha():Bool;

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
    function submitTexture2dPixels(level:Int, format:TextureFormat, width:Int, height:Int,
        dataType:TextureDataType, pixels:Uint8Array, premultipliedAlpha:Bool):Void;

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
    function submitCompressedTexture2dPixels(level:Int, format:TextureFormat, width:Int, height:Int,
        pixels:Uint8Array, premultipliedAlpha:Bool):Void;

    /**
     * Fetches 2D texture pixels from the GPU.
     *
     * @param into Buffer to store pixel data (must be at least w * h * 4 bytes)
     * @param x X position of texture rectangle to fetch
     * @param y Y position of texture rectangle to fetch
     * @param w Width of texture rectangle to fetch
     * @param h Height of texture rectangle to fetch
     */
    function fetchTexture2dPixels(into:Uint8Array, x:Int, y:Int, w:Int, h:Int):Void;

    /**
     * Sets the minification filter for 2D textures.
     *
     * @param minFilter Filter mode (NEAREST, LINEAR, or mipmap variants)
     */
    function setTexture2dMinFilter(minFilter:TextureFilter):Void;

    /**
     * Sets the magnification filter for 2D textures.
     *
     * @param magFilter Filter mode (NEAREST or LINEAR)
     */
    function setTexture2dMagFilter(magFilter:TextureFilter):Void;

    /**
     * Sets the horizontal (S) texture wrap mode.
     *
     * @param wrapS Wrap mode (CLAMP_TO_EDGE, REPEAT, or MIRRORED_REPEAT)
     */
    function setTexture2dWrapS(wrapS:TextureWrap):Void;

    /**
     * Sets the vertical (T) texture wrap mode.
     *
     * @param wrapT Wrap mode (CLAMP_TO_EDGE, REPEAT, or MIRRORED_REPEAT)
     */
    function setTexture2dWrapT(wrapT:TextureWrap):Void;

    // ========================================================================
    // Shader Management
    // ========================================================================

    #if clay_shader_from_source
    /**
     * Creates and compiles a shader program from source code.
     *
     * Only available when clay_shader_from_source is defined.
     * Used on platforms that support runtime shader compilation (OpenGL/WebGL).
     *
     * @param vertSource Vertex shader source code
     * @param fragSource Fragment shader source code
     * @param attributes Optional array of attribute names in binding order
     * @param textures Optional array of texture uniform names in slot order
     * @return Compiled shader, or null on failure
     */
    function createShader(vertSource:String, fragSource:String, ?attributes:Array<String>, ?textures:Array<String>):GpuShader;
    #else
    /**
     * Loads a precompiled shader program by identifier.
     *
     * Only available when clay_shader_from_source is NOT defined.
     * Used on platforms with precompiled shaders (consoles, Metal, Vulkan).
     *
     * @param shaderId Identifier for the precompiled shader (e.g., asset path or name)
     * @param attributes Optional array of attribute names in binding order
     * @param textures Optional array of texture uniform names in slot order
     * @return Loaded shader, or null on failure
     */
    function loadShader(shaderId:String, ?attributes:Array<String>, ?textures:Array<String>):GpuShader;
    #end

    /**
     * Deletes a shader program from the GPU.
     *
     * @param shader Shader program to delete
     */
    function deleteShader(shader:GpuShader):Void;

    /**
     * Activates a shader program for subsequent draw operations.
     *
     * @param shader Shader program to use
     */
    function useShader(shader:GpuShader):Void;

    /**
     * Synchronizes projectionMatrix and modelViewMatrix
     * with the given shader, as this is needed on some graphics backend.
     * @param shader Shader program to synchronize
     */
    function synchronizeShaderMatrices(shader:GpuShader):Void;

    /**
     * Gets the location of a uniform variable in a shader.
     *
     * @param shader Shader program
     * @param name Uniform variable name
     * @return Uniform location, or noLocation if not found
     */
    function getUniformLocation(shader:GpuShader, name:String):UniformLocation;

    /**
     * Sets an integer uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Integer value
     */
    function setIntUniform(shader:GpuShader, location:UniformLocation, value:Int):Void;

    /**
     * Sets an integer array uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Integer array
     */
    function setIntArrayUniform(shader:GpuShader, location:UniformLocation, value:Int32Array):Void;

    /**
     * Sets a float uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Float value
     */
    function setFloatUniform(shader:GpuShader, location:UniformLocation, value:Float):Void;

    /**
     * Sets a float array uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Float array
     */
    function setFloatArrayUniform(shader:GpuShader, location:UniformLocation, value:Float32Array):Void;

    /**
     * Sets a 2D vector uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param x X component
     * @param y Y component
     */
    function setVector2Uniform(shader:GpuShader, location:UniformLocation, x:Float, y:Float):Void;

    /**
     * Sets a 3D vector uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param x X component
     * @param y Y component
     * @param z Z component
     */
    function setVector3Uniform(shader:GpuShader, location:UniformLocation, x:Float, y:Float, z:Float):Void;

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
    function setVector4Uniform(shader:GpuShader, location:UniformLocation, x:Float, y:Float, z:Float, w:Float):Void;

    /**
     * Sets a color uniform value (RGBA).
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param r Red component (0.0 to 1.0)
     * @param g Green component (0.0 to 1.0)
     * @param b Blue component (0.0 to 1.0)
     * @param a Alpha component (0.0 to 1.0)
     */
    function setColorUniform(shader:GpuShader, location:UniformLocation, r:Float, g:Float, b:Float, a:Float):Void;

    /**
     * Sets a 4x4 matrix uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param value Matrix as Float32Array (16 elements, column-major)
     */
    function setMatrix4Uniform(shader:GpuShader, location:UniformLocation, value:Float32Array):Void;

    /**
     * Sets a texture sampler uniform value.
     *
     * @param shader Shader program
     * @param location Uniform location
     * @param slot Texture slot index
     * @param texture Texture identifier to bind
     */
    function setTexture2dUniform(shader:GpuShader, location:UniformLocation, slot:Int, texture:TextureId):Void;

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
    function createRenderTarget(textureId:TextureId, width:Int, height:Int, depth:Bool, stencil:Bool,
        antialiasing:Int, level:Int, format:TextureFormat, dataType:TextureDataType):RenderTarget;

    /**
     * Deletes a render target from the GPU.
     *
     * @param renderTarget Render target to delete
     */
    function deleteRenderTarget(renderTarget:RenderTarget):Void;

    /**
     * Sets the render target for subsequent draw operations.
     *
     * @param renderTarget Render target to draw into, or null for main framebuffer
     */
    function setRenderTarget(renderTarget:RenderTarget):Void;

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
    function configureRenderTargetBuffersStorage(renderTarget:RenderTarget, textureId:TextureId,
        width:Int, height:Int, depth:Bool, stencil:Bool, antialiasing:Int):Void;

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
    function blitRenderTargetBuffers(renderTarget:RenderTarget, width:Int, height:Int):Void;

    // ========================================================================
    // Framebuffer/Renderbuffer Management
    // ========================================================================

    /**
     * Creates a new framebuffer object.
     *
     * @return Created framebuffer
     */
    function createFramebuffer():Framebuffer;

    /**
     * Binds a framebuffer for rendering.
     *
     * @param framebuffer Framebuffer to bind, or noFramebuffer for default
     */
    function bindFramebuffer(framebuffer:Framebuffer):Void;

    /**
     * Creates a new renderbuffer object.
     *
     * @return Created renderbuffer
     */
    function createRenderbuffer():Renderbuffer;

    /**
     * Binds a renderbuffer.
     *
     * @param renderbuffer Renderbuffer to bind, or noRenderbuffer for default
     */
    function bindRenderbuffer(renderbuffer:Renderbuffer):Void;

    // ========================================================================
    // Error Checking
    // ========================================================================

    /**
     * Checks for and throws on any pending graphics errors.
     *
     * Useful for debugging graphics operations.
     */
    function ensureNoError():Void;

    // ========================================================================
    // Constants / Sentinel Values
    // ========================================================================

    /**
     * Sentinel value representing no texture bound.
     */
    var noTexture(get, never):TextureId;

    /**
     * Sentinel value representing the default framebuffer.
     */
    var noFramebuffer(get, never):Framebuffer;

    /**
     * Sentinel value representing the default renderbuffer.
     */
    var noRenderbuffer(get, never):Renderbuffer;

    /**
     * Sentinel value representing no shader handle.
     */
    var noShader(get, never):ShaderHandle;

    /**
     * Sentinel value representing no program handle.
     */
    var noProgram(get, never):ProgramHandle;

    /**
     * Sentinel value representing an invalid uniform location.
     */
    var noLocation(get, never):UniformLocation;

    /**
     * Sentinel value representing no buffer bound.
     */
    var noBuffer(get, never):BufferHandle;
}
