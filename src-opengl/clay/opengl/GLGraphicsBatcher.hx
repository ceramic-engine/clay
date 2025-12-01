package clay.opengl;

import clay.Types;
import clay.buffers.ArrayBufferView;
import clay.buffers.Float32Array;
import clay.buffers.Uint16Array;
import clay.opengl.GL;

/**
 * OpenGL implementation of the graphics batcher for batched rendering.
 *
 * This class handles all OpenGL rendering operations for batched geometry,
 * including vertex buffer management, texture binding, shader operations,
 * render targets, and batch rendering optimization.
 *
 * Key features:
 * - Efficient batch rendering with automatic buffer management
 * - Support for multi-texture batching
 * - Render-to-texture capabilities
 * - Stencil buffer operations for masking
 * - Custom shader attribute support
 * - Scissor testing for clipping
 * - Blend mode management
 *
 * The class uses a buffer cycling system to avoid GPU stalls and provides
 * platform-specific optimizations for different targets (web, desktop, mobile).
 *
 * This class implements `clay.spec.GraphicsBatcher` for compile-time API checking.
 * All methods are inlined for performance.
 */
class GLGraphicsBatcher implements clay.spec.GraphicsBatcher {

    // ========================================================================
    // Constants
    // ========================================================================

    /**
     * Maximum number of vertices that can be stored in a single buffer.
     */
    public static inline var MAX_VERTS_SIZE:Int = 65536;

    /**
     * Maximum number of indices that can be stored in a single buffer.
     */
    public static inline var MAX_INDICES:Int = 16384;

    /**
     * Maximum number of buffer sets to cycle through.
     * Buffer cycling prevents GPU stalls by using multiple buffer sets.
     */
    public static inline var MAX_BUFFERS:Int = 64;

    /**
     * Vertex attribute location for position data (x, y, z).
     */
    public static inline var ATTRIBUTE_POS:Int = 0;

    /**
     * Vertex attribute location for texture coordinate data (u, v).
     */
    public static inline var ATTRIBUTE_UV:Int = 1;

    /**
     * Vertex attribute location for color data (r, g, b, a).
     */
    public static inline var ATTRIBUTE_COLOR:Int = 2;

    // ========================================================================
    // Buffer Arrays (Instance State)
    // ========================================================================

    #if cpp
    var _viewPosBufferViewArray:Array<ArrayBufferView> = [];
    var _viewUvsBufferViewArray:Array<ArrayBufferView> = [];
    var _viewColorsBufferViewArray:Array<ArrayBufferView> = [];
    var _viewIndicesBufferViewArray:Array<ArrayBufferView> = [];

    var _viewPosBufferView:ArrayBufferView;
    var _viewUvsBufferView:ArrayBufferView;
    var _viewColorsBufferView:ArrayBufferView;
    var _viewIndicesBufferView:ArrayBufferView;
    #end

    var _buffersIndex:Int;

    var _posListArray:Array<Float32Array> = [];
    var _indiceListArray:Array<Uint16Array> = [];
    var _uvListArray:Array<Float32Array> = [];
    var _colorListArray:Array<Float32Array> = [];

    var _posList:Float32Array;
    var _indiceList:Uint16Array;
    var _uvList:Float32Array;
    var _colorList:Float32Array;

    #if cpp
    var _posBuffer:clay.buffers.ArrayBuffer;
    var _indiceBuffer:clay.buffers.ArrayBuffer;
    var _uvBuffer:clay.buffers.ArrayBuffer;
    var _colorBuffer:clay.buffers.ArrayBuffer;
    #end

    // ========================================================================
    // Batch State
    // ========================================================================

    var _batchMultiTexture:Bool = false;
    var _posSize:Int = 0;
    var _customGLBuffers:Array<GLBuffer> = [];
    var _customAttributes:Array<Dynamic> = null;

    var _maxVerts:Int = 0;
    var _vertexSize:Int = 0;
    var _numIndices:Int = 0;

    var _numPos:Int = 0;
    var _posIndex:Int = 0;
    var _floatAttributesSize:Int = 0;

    var _currentShader:GpuShader = null;

    /**
     * Default texture ID to use when no texture is bound.
     * On web targets, WebGL requires a texture to be bound, so this should
     * be set to a 1x1 white texture. On native targets, this can be left as null/0.
     */
    public static var defaultTextureId:TextureId = #if clay_web null #else 0 #end;

    var _numUVs:Int = 0;
    var _uvIndex:Int = 0;

    var _numColors:Int = 0;
    var _colorIndex:Int = 0;

    var _primitiveType:Int = GL.TRIANGLES;

    // ========================================================================
    // Initialization & Frame Lifecycle
    // ========================================================================

    /**
     * Creates a new GLGraphicsBatcher instance.
     */
    public function new() {}

    /**
     * Initializes the vertex and index buffers for rendering.
     *
     * This method sets up the buffer management system and prepares
     * the first set of buffers for use. Should be called before any
     * rendering operations begin.
     */
    public inline function initBuffers():Void {
        _buffersIndex = -1;
        prepareNextBuffers();
    }

    /**
     * Prepares the next set of vertex buffers for use.
     *
     * This implements a buffer cycling system to avoid GPU stalls. Instead of
     * reusing the same buffer immediately (which could cause the GPU to wait),
     * it cycles through multiple buffer sets.
     *
     * Buffer allocation:
     * - Position buffer: Full vertex capacity (MAX_VERTS_SIZE)
     * - UV buffer: 2/3 of vertex capacity (optimized for quads)
     * - Color buffer: Full vertex capacity (4 floats per vertex)
     * - Index buffer: MAX_INDICES * 2 capacity
     *
     * On C++ targets, additional ArrayBufferView objects are created for
     * efficient memory access without copying.
     */
    function prepareNextBuffers():Void {
        _buffersIndex++;
        if (_buffersIndex > MAX_BUFFERS) {
            _buffersIndex = 0;
        }
        if (_posListArray.length <= _buffersIndex) {
            _posListArray[_buffersIndex] = new Float32Array(MAX_VERTS_SIZE);
            // For uvs, we'll never need more than two thirds of vertex buffer size
            _uvListArray[_buffersIndex] = new Float32Array(Std.int(Math.ceil(MAX_VERTS_SIZE * 2.0 / 3.0)));
            _colorListArray[_buffersIndex] = new Float32Array(MAX_VERTS_SIZE);
            _indiceListArray[_buffersIndex] = new Uint16Array(MAX_INDICES * 2);

            #if cpp
            _viewPosBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewUvsBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewColorsBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewIndicesBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Uint8);
            #end
        }

        _posList = _posListArray[_buffersIndex];
        _uvList = _uvListArray[_buffersIndex];
        _colorList = _colorListArray[_buffersIndex];
        _indiceList = _indiceListArray[_buffersIndex];

        #if cpp
        _viewPosBufferView = _viewPosBufferViewArray[_buffersIndex];
        _viewUvsBufferView = _viewUvsBufferViewArray[_buffersIndex];
        _viewColorsBufferView = _viewColorsBufferViewArray[_buffersIndex];
        _viewIndicesBufferView = _viewIndicesBufferViewArray[_buffersIndex];

        _posBuffer = (_posList:clay.buffers.ArrayBufferView).buffer;
        _uvBuffer = (_uvList:clay.buffers.ArrayBufferView).buffer;
        _colorBuffer = (_colorList:clay.buffers.ArrayBufferView).buffer;
        _indiceBuffer = (_indiceList:clay.buffers.ArrayBufferView).buffer;
        #end
    }

    /**
     * Begins a rendering pass by enabling vertex attributes.
     *
     * Enables the core vertex attributes used by all shaders:
     * - Position (x, y, z)
     * - Texture coordinates (u, v)
     * - Color (r, g, b, a)
     *
     * Additional attributes are enabled dynamically based on the active shader.
     */
    public inline function beginRender():Void {
        GL.enableVertexAttribArray(ATTRIBUTE_POS);
        GL.enableVertexAttribArray(ATTRIBUTE_UV);
        GL.enableVertexAttribArray(ATTRIBUTE_COLOR);
    }

    /**
     * Ends the current rendering frame.
     *
     * Performs any cleanup or finalization needed after all draw operations.
     * Currently a no-op for OpenGL, but provided for API completeness.
     */
    public inline function endRender():Void {
        // No-op for OpenGL
    }

    // ========================================================================
    // Vertex Layout Configuration
    // ========================================================================

    /**
     * Configures the vertex layout for the current shader.
     *
     * This determines how vertex data is structured in the buffer,
     * including support for multi-texture batching and custom attributes.
     *
     * The vertex size calculation includes:
     * - 3 floats for position (x, y, z)
     * - Custom float attributes defined by the shader
     * - 1 float for texture slot (if multi-texturing is enabled)
     *
     * @param hasTextureSlot Whether vertices include a texture slot for multi-texture batching
     * @param customFloatAttributesSize Number of custom float attributes per vertex
     */
    public inline function setVertexLayout(hasTextureSlot:Bool, customFloatAttributesSize:Int):Void {
        _floatAttributesSize = customFloatAttributesSize;
        _batchMultiTexture = hasTextureSlot;
        _vertexSize = 3 + _floatAttributesSize + (_batchMultiTexture ? 1 : 0);
        _posSize = _vertexSize;
        if (_vertexSize < 4)
            _vertexSize = 4;

        _maxVerts = Std.int(Math.floor(MAX_VERTS_SIZE / _vertexSize));

        if (_numPos == 0) {
            resetIndexes();
        }
    }

    /**
     * Sets the custom shader attributes for vertex layout.
     *
     * These attributes define how custom per-vertex data is structured
     * in the position buffer. Used by shaders that require additional
     * vertex data beyond position, UV, and color.
     *
     * @param attributes Array of shader attributes, or null for none
     */
    public inline function setCustomAttributes(attributes:Array<Dynamic>):Void {
        _customAttributes = attributes;
    }

    /**
     * Resets all vertex buffer indexes to zero.
     *
     * This prepares the buffers for a new batch of vertices.
     * Called when starting a new draw batch or after flushing.
     */
    inline function resetIndexes():Void {
        _numIndices = 0;
        _numPos = 0;
        _numUVs = 0;
        _numColors = 0;

        _posIndex = 0;
        _uvIndex = 0;
        _colorIndex = 0;
    }

    // ========================================================================
    // Vertex Submission
    // ========================================================================

    /**
     * Adds a vertex position to the current batch.
     *
     * On C++ targets, uses direct memory access for performance.
     * On other targets, uses array access.
     *
     * @param x X coordinate in screen space
     * @param y Y coordinate in screen space
     * @param z Z coordinate for depth ordering
     */
    public inline function putVertex(x:Float, y:Float, z:Float):Void {
        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, _posIndex * Float32Array.BYTES_PER_ELEMENT, x);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 1) * Float32Array.BYTES_PER_ELEMENT, y);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 2) * Float32Array.BYTES_PER_ELEMENT, z);
        #else
        _posList[_posIndex] = x;
        _posList[_posIndex + 1] = y;
        _posList[_posIndex + 2] = z;
        #end
        _posIndex += 3;
        _numPos++;
    }

    /**
     * Adds a vertex position with texture slot for multi-texture batching.
     *
     * @param x X coordinate in screen space
     * @param y Y coordinate in screen space
     * @param z Z coordinate for depth ordering
     * @param textureSlot Texture slot index for multi-texture batching
     */
    public inline function putVertexWithTextureSlot(x:Float, y:Float, z:Float, textureSlot:Float):Void {
        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, _posIndex * Float32Array.BYTES_PER_ELEMENT, x);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 1) * Float32Array.BYTES_PER_ELEMENT, y);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 2) * Float32Array.BYTES_PER_ELEMENT, z);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 3) * Float32Array.BYTES_PER_ELEMENT, textureSlot);
        #else
        _posList[_posIndex] = x;
        _posList[_posIndex + 1] = y;
        _posList[_posIndex + 2] = z;
        _posList[_posIndex + 3] = textureSlot;
        #end
        _posIndex += 4;
        _numPos++;
    }

    /**
     * Adds texture coordinates for the current vertex.
     *
     * @param u Horizontal texture coordinate (0.0 to 1.0)
     * @param v Vertical texture coordinate (0.0 to 1.0)
     */
    public inline function putUVs(u:Float, v:Float):Void {
        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_uvBuffer, _uvIndex * Float32Array.BYTES_PER_ELEMENT, u);
        clay.buffers.ArrayBufferIO.setFloat32(_uvBuffer, (_uvIndex + 1) * Float32Array.BYTES_PER_ELEMENT, v);
        #else
        _uvList[_uvIndex] = u;
        _uvList[_uvIndex + 1] = v;
        #end
        _uvIndex += 2;
        _numUVs++;
    }

    /**
     * Adds color data for the current vertex.
     *
     * Colors are stored as floating-point values from 0.0 to 1.0.
     * The color will be interpolated across the triangle/line.
     *
     * @param r Red component (0.0 to 1.0)
     * @param g Green component (0.0 to 1.0)
     * @param b Blue component (0.0 to 1.0)
     * @param a Alpha component (0.0 to 1.0)
     */
    public inline function putColor(r:Float, g:Float, b:Float, a:Float):Void {
        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, _colorIndex * Float32Array.BYTES_PER_ELEMENT, r);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 1) * Float32Array.BYTES_PER_ELEMENT, g);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 2) * Float32Array.BYTES_PER_ELEMENT, b);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 3) * Float32Array.BYTES_PER_ELEMENT, a);
        #else
        _colorList[_colorIndex] = r;
        _colorList[_colorIndex + 1] = g;
        _colorList[_colorIndex + 2] = b;
        _colorList[_colorIndex + 3] = a;
        #end
        _colorIndex += 4;
        _numColors++;
    }

    /**
     * Adds an index to the index buffer.
     * Indices reference vertices in the vertex buffer to form primitives.
     *
     * @param i Vertex index
     */
    public inline function putIndex(i:Int):Void {
        #if cpp
        clay.buffers.ArrayBufferIO.setUint16(_indiceBuffer, _numIndices * Uint16Array.BYTES_PER_ELEMENT, i);
        #else
        _indiceList[_numIndices] = i;
        #end
        _numIndices++;
    }

    /**
     * Adds a custom float attribute value for the current vertex.
     * Used with custom shaders that require additional per-vertex data.
     *
     * @param index Attribute index (as defined by the shader)
     * @param value Attribute value
     */
    public inline function putFloatAttribute(index:Int, value:Float):Void {
        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + index) * Float32Array.BYTES_PER_ELEMENT, value);
        #else
        _posList[_posIndex + index] = value;
        #end
    }

    /**
     * Signals the end of custom float attributes for the current vertex.
     * Must be called after all putFloatAttribute() calls for a vertex.
     */
    public inline function endFloatAttributes():Void {
        _posIndex += _floatAttributesSize;
    }

    // ========================================================================
    // Batch State Queries
    // ========================================================================

    /**
     * Gets the number of vertices currently in the buffer.
     *
     * @return Current vertex count
     */
    public inline function getNumVertices():Int {
        return _numPos;
    }

    /**
     * Checks if the buffer should be flushed before adding more geometry.
     *
     * Returns true if adding the specified number of vertices or indices
     * would exceed buffer capacity, indicating that the current batch
     * should be sent to the GPU before continuing.
     *
     * @param numVerticesAfter Number of vertices to be added
     * @param numIndicesAfter Number of indices to be added
     * @return True if flush is needed, false otherwise
     */
    public inline function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int):Bool {
        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > MAX_INDICES);
    }

    /**
     * Gets the remaining vertex capacity in the buffer.
     *
     * @return Number of vertices that can still be added
     */
    public inline function remainingVertices():Int {
        return _maxVerts - _numPos;
    }

    /**
     * Gets the remaining index capacity in the buffer.
     *
     * @return Number of indices that can still be added
     */
    public inline function remainingIndices():Int {
        return MAX_INDICES - _numIndices;
    }

    /**
     * Checks if there is any geometry in the buffer to flush.
     *
     * @return True if there are vertices/indices waiting to be submitted
     */
    public inline function hasAnythingToFlush():Bool {
        return _numPos > 0;
    }

    // ========================================================================
    // Draw Submission
    // ========================================================================

    /**
     * Flushes the current batch of vertices to the GPU.
     *
     * This is the core rendering method that:
     * 1. Creates GPU buffers from the accumulated vertex data
     * 2. Configures vertex attributes for the shader
     * 3. Handles multi-texture batching if supported
     * 4. Sets up custom shader attributes
     * 5. Issues the draw call to render all triangles/lines
     * 6. Cleans up temporary buffers
     * 7. Prepares for the next batch
     *
     * The method uses temporary GPU buffers that are deleted after
     * rendering to avoid memory leaks. Buffer data is uploaded as
     * STREAM_DRAW for optimal performance with dynamic geometry.
     */
    public function flush():Void {
        var batchMultiTexture = _batchMultiTexture;

        // fromBuffer takes byte length, so floats * 4
        #if cpp
        var pos = Float32Array.fromBuffer(_posBuffer, 0, _posIndex * 4, _viewPosBufferView);
        var uvs = Float32Array.fromBuffer(_uvBuffer, 0, _uvIndex * 4, _viewUvsBufferView);
        var colors = Float32Array.fromBuffer(_colorBuffer, 0, _colorIndex * 4, _viewColorsBufferView);
        var indices = Uint16Array.fromBuffer(_indiceBuffer, 0, _numIndices * 2, _viewIndicesBufferView);
        #else
        var pos = Float32Array.fromBuffer(_posList.buffer, 0, _posIndex * 4);
        var uvs = Float32Array.fromBuffer(_uvList.buffer, 0, _uvIndex * 4);
        var colors = Float32Array.fromBuffer(_colorList.buffer, 0, _colorIndex * 4);
        var indices = Uint16Array.fromBuffer(_indiceList.buffer, 0, _numIndices * 2);
        #end

        // Begin submit

        var pb = GL.createBuffer();
        var cb = GL.createBuffer();
        var tb = GL.createBuffer();
        var ib = GL.createBuffer();

        GL.enableVertexAttribArray(0);
        GL.enableVertexAttribArray(1);
        GL.enableVertexAttribArray(2);

        GL.bindBuffer(GL.ARRAY_BUFFER, pb);
        GL.vertexAttribPointer(ATTRIBUTE_POS, 3, GL.FLOAT, false, _posSize * 4, 0);
        GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, tb);
        GL.vertexAttribPointer(ATTRIBUTE_UV, 2, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, uvs, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, cb);
        GL.vertexAttribPointer(ATTRIBUTE_COLOR, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, colors, GL.STREAM_DRAW);

        var offset = 3;
        var n = ATTRIBUTE_COLOR + 1;
        var customGLBuffersLen:Int = 0;

        if (batchMultiTexture) {
            var b = GL.createBuffer();
            _customGLBuffers[customGLBuffersLen++] = b;

            GL.enableVertexAttribArray(n);
            GL.bindBuffer(GL.ARRAY_BUFFER, b);
            GL.vertexAttribPointer(n, 1, GL.FLOAT, false, _posSize * 4, offset * 4);
            GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

            n++;
            offset++;
        }

        if (_customAttributes != null) {
            var allAttrs = _customAttributes;
            var start = customGLBuffersLen;
            var end = start + allAttrs.length;
            customGLBuffersLen += allAttrs.length;
            for (ii in start...end) {
                var attrIndex = ii - start;
                var attr = allAttrs[attrIndex];

                var b = GL.createBuffer();
                _customGLBuffers[ii] = b;

                GL.enableVertexAttribArray(n);
                GL.bindBuffer(GL.ARRAY_BUFFER, b);
                GL.vertexAttribPointer(n, attr.size, GL.FLOAT, false, _posSize * 4, offset * 4);
                GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

                n++;
                offset += attr.size;
            }
        }

        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ib);
        GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indices, GL.STREAM_DRAW);

        // Draw
        GL.drawElements(_primitiveType, _numIndices, GL.UNSIGNED_SHORT, 0);

        GL.deleteBuffer(pb);
        GL.deleteBuffer(cb);
        GL.deleteBuffer(tb);

        if (customGLBuffersLen > 0) {
            var n = ATTRIBUTE_COLOR + 1;
            for (ii in 0...customGLBuffersLen) {
                var b = _customGLBuffers[ii];
                GL.deleteBuffer(b);
                GL.disableVertexAttribArray(n);
                n++;
            }
        }

        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, Clay.app.graphics.noBuffer);
        GL.deleteBuffer(ib);

        // End submit

        pos = null;
        uvs = null;
        colors = null;
        indices = null;

        resetIndexes();

        prepareNextBuffers();
    }

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
    public inline function clear(r:Float, g:Float, b:Float, a:Float, clearDepth:Bool):Void {
        Clay.app.graphics.clear(r, g, b, a, clearDepth);
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
        Clay.app.graphics.setViewport(x, y, width, height);
    }

    /**
     * Sets the primitive type for rendering.
     *
     * @param primitiveType 0 for triangles, 1 for lines
     */
    public inline function setPrimitiveType(primitiveType:Int):Void {
        _primitiveType = switch primitiveType {
            case 1: GL.LINES;
            case _: GL.TRIANGLES;
        }
    }

    // ========================================================================
    // Blending
    // ========================================================================

    /**
     * Enables alpha blending for subsequent draw operations.
     */
    public inline function enableBlending():Void {
        Clay.app.graphics.enableBlending();
    }

    /**
     * Disables alpha blending for subsequent draw operations.
     */
    public inline function disableBlending():Void {
        Clay.app.graphics.disableBlending();
    }

    /**
     * Sets separate blend functions for RGB and alpha channels.
     *
     * @param srcRgb Source blend factor for RGB channels
     * @param dstRgb Destination blend factor for RGB channels
     * @param srcAlpha Source blend factor for alpha channel
     * @param dstAlpha Destination blend factor for alpha channel
     */
    public inline function setBlendFuncSeparate(srcRgb:Int, dstRgb:Int, srcAlpha:Int, dstAlpha:Int):Void {
        Clay.app.graphics.setBlendFuncSeparate(srcRgb, dstRgb, srcAlpha, dstAlpha);
    }

    // ========================================================================
    // Textures
    // ========================================================================

    /**
     * Sets the active texture slot for multi-texturing.
     *
     * @param slot Texture slot index (0-based)
     */
    public inline function setActiveTexture(slot:Int):Void {
        Clay.app.graphics.setActiveTexture(slot);
    }

    /**
     * Binds a texture to the current texture slot.
     *
     * @param textureId Texture identifier to bind
     */
    public inline function bindTexture(textureId:TextureId):Void {
        Clay.app.graphics.bindTexture2d(textureId);
    }

    /**
     * Unbinds any texture from the current texture slot.
     * Uses the defaultTextureId which should be set to a white texture on web targets.
     */
    public inline function bindNoTexture():Void {
        Clay.app.graphics.bindTexture2d(defaultTextureId);
    }

    // ========================================================================
    // Render Targets
    // ========================================================================

    /**
     * Sets the render target for subsequent draw operations.
     *
     * @param renderTarget Render target to draw into, or null for main framebuffer
     */
    public inline function setRenderTarget(renderTarget:RenderTarget):Void {
        Clay.app.graphics.setRenderTarget(renderTarget);
    }

    /**
     * Resolves MSAA render target buffers.
     * Called when switching away from an antialiased render target.
     *
     * @param renderTarget The render target to resolve
     * @param width Width of the render target
     * @param height Height of the render target
     */
    public inline function blitRenderTargetBuffers(renderTarget:RenderTarget, width:Int, height:Int):Void {
        Clay.app.graphics.blitRenderTargetBuffers(renderTarget, width, height);
    }

    // ========================================================================
    // Shaders
    // ========================================================================

    /**
     * Activates a shader program for subsequent draw operations.
     *
     * @param shader Shader program to use
     */
    public inline function useShader(shader:GpuShader):Void {
        _currentShader = shader;
        Clay.app.graphics.useShader(shader);
    }

    /**
     * Sets the projection matrix uniform.
     *
     * @param matrix 4x4 projection matrix as Float32Array (16 elements)
     */
    public inline function setProjectionMatrix(matrix:Float32Array):Void {
        GL.uniformMatrix4fv(GL.getUniformLocation(_currentShader.program, "projectionMatrix"), false, matrix);
    }

    /**
     * Sets the model-view matrix uniform.
     *
     * @param matrix 4x4 model-view matrix as Float32Array (16 elements)
     */
    public inline function setModelViewMatrix(matrix:Float32Array):Void {
        GL.uniformMatrix4fv(GL.getUniformLocation(_currentShader.program, "modelViewMatrix"), false, matrix);
    }

    // ========================================================================
    // Stencil
    // ========================================================================

    /**
     * Begins writing to the stencil buffer.
     * Subsequent draw calls will write to stencil instead of color buffer.
     */
    public inline function beginStencilWrite():Void {
        GL.stencilMask(0xFF);
        GL.clearStencil(0xFF);
        GL.clear(GL.STENCIL_BUFFER_BIT);
        GL.enable(GL.STENCIL_TEST);

        GL.stencilOp(GL.KEEP, GL.KEEP, GL.REPLACE);

        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(false, false, false, false);
    }

    /**
     * Ends writing to the stencil buffer.
     * Returns to normal color buffer rendering.
     */
    public inline function endStencilWrite():Void {
        // No-op - state is managed by enableStencilTest/disableStencilTest
    }

    /**
     * Enables stencil testing for subsequent draw operations.
     * Only pixels passing the stencil test will be rendered.
     */
    public inline function enableStencilTest():Void {
        GL.stencilFunc(GL.EQUAL, 1, 0xFF);
        GL.stencilMask(0x00);
        GL.colorMask(true, true, true, true);

        GL.enable(GL.STENCIL_TEST);
    }

    /**
     * Disables stencil testing for subsequent draw operations.
     */
    public inline function disableStencilTest():Void {
        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(true, true, true, true);

        GL.disable(GL.STENCIL_TEST);
    }

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
    public inline function enableScissor(x:Float, y:Float, width:Float, height:Float):Void {
        GL.enable(GL.SCISSOR_TEST);
        GL.scissor(Math.round(x), Math.round(y), Math.round(width), Math.round(height));
    }

    /**
     * Disables scissor testing.
     */
    public inline function disableScissor():Void {
        GL.disable(GL.SCISSOR_TEST);
    }
}
