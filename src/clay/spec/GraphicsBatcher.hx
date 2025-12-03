package clay.spec;

import clay.Types;
import clay.buffers.Float32Array;

/**
 * Interface for graphics batcher implementations.
 *
 * Provides a unified API for batched rendering across different graphics backends
 * (OpenGL, D3D12, etc.). Each backend would implement this interface with
 * platform-specific optimizations.
 *
 * The graphics batcher manages vertex/index data accumulation and submission to the GPU.
 * It handles buffer cycling to prevent GPU stalls and supports multi-texture batching.
 *
 * Typical usage flow:
 * 1. initBuffers() - Initialize at startup
 * 2. beginRender() - Start frame
 * 3. Configure state (shader, textures, blend mode)
 * 4. Submit vertices via putVertex(), putUVs(), putColor(), putIndex()
 * 5. flush() when buffers full or state changes
 * 6. endRender() - End frame
 */
interface GraphicsBatcher {

    // ========================================================================
    // Initialization & Frame Lifecycle
    // ========================================================================

    /**
     * Initializes vertex and index buffers.
     * Called once during startup to allocate GPU resources.
     */
    function initBuffers():Void;

    /**
     * Begins a new rendering frame.
     * Enables vertex attributes and prepares for draw operations.
     */
    function beginRender():Void;

    /**
     * Ends the current rendering frame.
     * Performs any cleanup or finalization needed after all draw operations.
     */
    function endRender():Void;

    // ========================================================================
    // Vertex Layout Configuration
    // ========================================================================

    /**
     * Configures the vertex layout for the current shader.
     *
     * This determines how vertex data is structured in the buffer,
     * including support for multi-texture batching and custom attributes.
     *
     * @param hasTextureSlot Whether vertices include a texture slot for multi-texture batching
     * @param customFloatAttributesSize Number of custom float attributes per vertex
     */
    function setVertexLayout(hasTextureSlot:Bool, customFloatAttributesSize:Int):Void;

    /**
     * Sets the custom shader attributes for vertex layout.
     *
     * These attributes define how custom per-vertex data is structured
     * in the position buffer. Used by shaders that require additional
     * vertex data beyond position, UV, and color.
     *
     * @param attributes Array of shader attributes (objects with 'size' field), or null for none
     */
    function setCustomAttributes(attributes:Array<Dynamic>):Void;

    // ========================================================================
    // Vertex Submission
    // ========================================================================

    /**
     * Adds a vertex position to the buffer.
     *
     * @param x X coordinate in screen space
     * @param y Y coordinate in screen space
     * @param z Z coordinate for depth ordering
     */
    function putVertex(x:Float, y:Float, z:Float):Void;

    /**
     * Adds a vertex position with texture slot for multi-texture batching.
     *
     * @param x X coordinate in screen space
     * @param y Y coordinate in screen space
     * @param z Z coordinate for depth ordering
     * @param textureSlot Texture slot index for multi-texture batching
     */
    function putVertexWithTextureSlot(x:Float, y:Float, z:Float, textureSlot:Float):Void;

    /**
     * Adds texture coordinates for the current vertex.
     *
     * @param u Horizontal texture coordinate (0.0 to 1.0)
     * @param v Vertical texture coordinate (0.0 to 1.0)
     */
    function putUVs(u:Float, v:Float):Void;

    /**
     * Adds color data for the current vertex.
     *
     * @param r Red component (0.0 to 1.0)
     * @param g Green component (0.0 to 1.0)
     * @param b Blue component (0.0 to 1.0)
     * @param a Alpha component (0.0 to 1.0)
     */
    function putColor(r:Float, g:Float, b:Float, a:Float):Void;

    /**
     * Adds an index to the index buffer.
     * Indices reference vertices in the vertex buffer to form primitives.
     *
     * @param i Vertex index
     */
    function putIndex(i:Int):Void;

    /**
     * Adds a custom float attribute value for the current vertex.
     * Used with custom shaders that require additional per-vertex data.
     *
     * @param index Attribute index (as defined by the shader)
     * @param value Attribute value
     */
    function putFloatAttribute(index:Int, value:Float):Void;

    /**
     * Signals the end of custom float attributes for the current vertex.
     * Must be called after all putFloatAttribute() calls for a vertex.
     */
    function endFloatAttributes():Void;

    // ========================================================================
    // Batch State Queries
    // ========================================================================

    /**
     * Gets the number of vertices currently in the buffer.
     *
     * @return Current vertex count
     */
    function getNumVertices():Int;

    /**
     * Checks if the buffer should be flushed before adding more geometry.
     *
     * @param numVerticesAfter Number of vertices to be added
     * @param numIndicesAfter Number of indices to be added
     * @return True if flush is needed before adding the geometry
     */
    function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int):Bool;

    /**
     * Gets the remaining vertex capacity in the buffer.
     *
     * @return Number of vertices that can still be added
     */
    function remainingVertices():Int;

    /**
     * Gets the remaining index capacity in the buffer.
     *
     * @return Number of indices that can still be added
     */
    function remainingIndices():Int;

    /**
     * Checks if there is any geometry in the buffer to flush.
     *
     * @return True if there are vertices/indices waiting to be submitted
     */
    function hasAnythingToFlush():Bool;

    // ========================================================================
    // Draw Submission
    // ========================================================================

    /**
     * Flushes all buffered geometry to the GPU.
     *
     * Submits accumulated vertex and index data as a draw call.
     * Should be called when:
     * - Buffers are full
     * - Render state changes (texture, shader, blend mode)
     * - Frame is complete
     */
    function flush():Void;

    // ========================================================================
    // Render State
    // ========================================================================

    /**
     * Clears the current render target.
     *
     * @param r Red component of clear color (0.0 to 1.0)
     * @param g Green component of clear color (0.0 to 1.0)
     * @param b Blue component of clear color (0.0 to 1.0)
     * @param a Alpha component of clear color (0.0 to 1.0)
     * @param clearDepth Whether to also clear the depth buffer
     */
    function clear(r:Float, g:Float, b:Float, a:Float, clearDepth:Bool):Void;

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
     * Sets the primitive type for rendering.
     *
     * @param primitiveType 0 for triangles, 1 for lines
     */
    function setPrimitiveType(primitiveType:Int):Void;

    // ========================================================================
    // Blending
    // ========================================================================

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
    function setBlendFuncSeparate(srcRgb:Int, dstRgb:Int, srcAlpha:Int, dstAlpha:Int):Void;

    // ========================================================================
    // Textures
    // ========================================================================

    /**
     * Sets the active texture slot for multi-texturing.
     *
     * @param slot Texture slot index (0-based)
     */
    function setActiveTexture(slot:Int):Void;

    /**
     * Binds a texture to the current texture slot.
     *
     * @param textureId Texture identifier to bind
     */
    function bindTexture(textureId:TextureId):Void;

    /**
     * Unbinds any texture from the current texture slot.
     * On some platforms, binds a default white texture instead.
     */
    function bindNoTexture():Void;

    // ========================================================================
    // Render Targets
    // ========================================================================

    /**
     * Returns `true` if render target
     * MVP matrix should be flipped vertically.
     */
    function shouldFlipRenderTargetY():Bool;

    /**
     * Sets the render target for subsequent draw operations.
     *
     * @param renderTarget Render target to draw into, or null for main framebuffer
     */
    function setRenderTarget(renderTarget:RenderTarget):Void;

    /**
     * Resolves MSAA render target buffers.
     * Called when switching away from an antialiased render target.
     *
     * @param renderTarget The render target to resolve
     * @param width Width of the render target
     * @param height Height of the render target
     */
    function blitRenderTargetBuffers(renderTarget:RenderTarget, width:Int, height:Int):Void;

    // ========================================================================
    // Shaders
    // ========================================================================

    /**
     * Activates a shader program for subsequent draw operations.
     *
     * @param shader Shader program to use
     */
    function useShader(shader:GpuShader):Void;

    /**
     * Sets the projection matrix uniform.
     *
     * @param matrix 4x4 projection matrix as Float32Array (16 elements)
     */
    function setProjectionMatrix(matrix:Float32Array):Void;

    /**
     * Sets the model-view matrix uniform.
     *
     * @param matrix 4x4 model-view matrix as Float32Array (16 elements)
     */
    function setModelViewMatrix(matrix:Float32Array):Void;

    // ========================================================================
    // Stencil
    // ========================================================================

    /**
     * Begins writing to the stencil buffer.
     * Subsequent draw calls will write to stencil instead of color buffer.
     */
    function beginStencilWrite():Void;

    /**
     * Ends writing to the stencil buffer.
     * Returns to normal color buffer rendering.
     */
    function endStencilWrite():Void;

    /**
     * Enables stencil testing for subsequent draw operations.
     * Only pixels passing the stencil test will be rendered.
     */
    function enableStencilTest():Void;

    /**
     * Disables stencil testing for subsequent draw operations.
     */
    function disableStencilTest():Void;

    // ========================================================================
    // Scissor
    // ========================================================================

    /**
     * Enables scissor testing with the specified rectangle.
     * Only pixels within this rectangle will be rendered.
     *
     * @param x Left edge of scissor rectangle
     * @param y Top edge of scissor rectangle
     * @param width Width of scissor rectangle
     * @param height Height of scissor rectangle
     */
    function enableScissor(x:Float, y:Float, width:Float, height:Float):Void;

    /**
     * Disables scissor testing.
     */
    function disableScissor():Void;
}
