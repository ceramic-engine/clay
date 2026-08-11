package clay.simd.wasm;

#if js

import js.lib.Float32Array;
import js.lib.Int32Array;
import js.lib.Uint32Array;
import js.lib.Uint8Array;
import js.lib.WebAssembly;
import js.lib.ArrayBuffer;

/**
 * Loader and memory manager for the wasm emission kernels (web target).
 *
 * The kernels are embedded as base64 (see kernel.c / build.sh) and
 * instantiated asynchronously at startup: until `ready` is true, callers
 * fall back to the plain js batched path. Feature detection picks the
 * SIMD build when the engine supports wasm SIMD (all evergreen browsers
 * since 2021, Safari 16.4+), the scalar wasm build otherwise.
 *
 * Memory model: this class owns the module's linear memory and hands out
 * regions through a simple bump allocator (`alloc`). The GL batcher
 * allocates its staging buffers as views over this memory, so the kernels
 * write in place and `gl.bufferData(view)` uploads with zero extra
 * copies. Per-part *source* copies (vertices/colors/uvs/indices into the
 * scratch regions) are done with typed-array `set` where possible, which
 * is nearly free browser-side.
 *
 * Growing the memory detaches every existing view: `memoryGeneration` is
 * bumped on growth and view holders (the batcher, the scratch views here)
 * must re-derive their views from their stored offsets when it changes.
 */
class WasmSimd {

    /** True once the module is instantiated and usable. */
    public static var ready(default, null):Bool = false;

    /** True when the SIMD build of the kernels is in use. */
    public static var usingSimd(default, null):Bool = false;

    /** Bumped every time the wasm memory grows (views must be re-derived). */
    public static var memoryGeneration(default, null):Int = 0;

    static var memory:Dynamic = null;
    static var meshPartF32Fn:Dynamic = null;

    static var bumpOffset:Int = 0;
    static var memoryBytes:Int = 0;

    // Per-part source scratch regions (re-derived on growth)
    static var vertsScratchOffset:Int = 0;
    static var vertsScratchFloats:Int = 0;
    static var colorsScratchOffset:Int = 0;
    static var colorsScratchFloats:Int = 0;
    static var uvsScratchOffset:Int = 0;
    static var uvsScratchFloats:Int = 0;
    static var indicesScratchOffset:Int = 0;
    static var indicesScratchInts:Int = 0;

    static var vertsScratchView:Float32Array = null;
    static var colorsScratchView:Float32Array = null;
    static var packedScratchView:Uint32Array = null;
    static var uvsScratchView:Float32Array = null;
    static var indicesScratchView:Int32Array = null;
    static var scratchGeneration:Int = -1;

    /** The wasm memory's ArrayBuffer (compare with a view's buffer to know if it is wasm-backed). */
    public static var memoryBuffer(get, never):ArrayBuffer;
    inline static function get_memoryBuffer():ArrayBuffer {
        return memory != null ? memory.buffer : null;
    }

    /**
     * Starts loading the kernels. Safe to call multiple times.
     */
    public static function init():Void {

        static var initStarted = false;
        if (initStarted) return;
        initStarted = true;

        // Feature-detect wasm SIMD with a tiny probe module
        var probe = new Uint8Array([
            0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 96, 0, 1, 123, 3, 2, 1, 0,
            10, 10, 1, 8, 0, 65, 0, 253, 15, 253, 98, 11
        ]);
        var simdOk = WebAssembly.validate(probe);
        #if ceramic_wasm_force_scalar
        // Measurement define: compile-time switch to the scalar wasm build
        // (isolates the wasm-vs-js gain from the SIMD gain)
        simdOk = false;
        #end

        var b64 = simdOk ? WasmSimdData.KERNEL_SIMD_B64 : WasmSimdData.KERNEL_SCALAR_B64;
        var binStr = js.Browser.window.atob(b64);
        var bytes = new Uint8Array(binStr.length);
        for (i in 0...binStr.length) {
            bytes[i] = binStr.charCodeAt(i);
        }

        WebAssembly.instantiate(bytes.buffer, {}).then(result -> {
            var instance:Dynamic = (cast result).instance;
            memory = instance.exports.memory;
            meshPartF32Fn = instance.exports.meshPartF32;

            // Reserve low memory for the module's own stack/globals, then
            // grow to a comfortable initial size for staging + scratch
            memoryBytes = (memory.buffer:ArrayBuffer).byteLength;
            bumpOffset = 1024 * 1024;
            ensureCapacity(8 * 1024 * 1024);

            usingSimd = simdOk;
            ready = true;
        }).catchError(e -> {
            // No wasm available: the js batched path stays in use
            ready = false;
        });

    }

    /**
     * Allocates `bytes` from the module memory (16-byte aligned).
     * Returns the byte offset, or -1 if the memory limit was reached
     * (in which case the whole wasm path is permanently disabled and
     * callers keep using the plain js path). Regions are never freed.
     */
    public static function alloc(bytes:Int):Int {

        var offset = bumpOffset;
        var newBump = bumpOffset + ((bytes + 15) & ~15);
        if (!ensureCapacity(newBump)) {
            return -1;
        }
        bumpOffset = newBump;
        return offset;

    }

    static function ensureCapacity(needed:Int):Bool {

        if (needed > memoryBytes) {
            try {
                var pages = Math.ceil((needed - memoryBytes) / 65536);
                memory.grow(pages);
                memoryBytes = (memory.buffer:ArrayBuffer).byteLength;
                memoryGeneration++;
            }
            catch (e:Dynamic) {
                // Memory limit reached: disable the wasm path for good
                // rather than failing during rendering; the js batched
                // path takes over transparently.
                ready = false;
                return false;
            }
        }
        return true;

    }

    /**
     * Scratch source regions for one mesh part, sized for at least
     * `numVertFloats` position floats, `numColorFloats` color floats,
     * `numUvFloats` uv floats and `numIndices` indices. Views are reused
     * across parts within a frame and re-derived after memory growth.
     */
    public static function requireScratch(numVertFloats:Int, numColorFloats:Int, numUvFloats:Int, numIndices:Int):Bool {

        if (numVertFloats > vertsScratchFloats) {
            vertsScratchFloats = nextPow2(numVertFloats);
            vertsScratchOffset = alloc(vertsScratchFloats * 4);
            scratchGeneration = -1;
        }
        if (numColorFloats > colorsScratchFloats) {
            colorsScratchFloats = nextPow2(numColorFloats);
            colorsScratchOffset = alloc(colorsScratchFloats * 4);
            scratchGeneration = -1;
        }
        if (numUvFloats > uvsScratchFloats) {
            uvsScratchFloats = nextPow2(numUvFloats);
            uvsScratchOffset = alloc(uvsScratchFloats * 4);
            scratchGeneration = -1;
        }
        if (numIndices > indicesScratchInts) {
            indicesScratchInts = nextPow2(numIndices);
            indicesScratchOffset = alloc(indicesScratchInts * 4);
            scratchGeneration = -1;
        }

        if (!ready || vertsScratchOffset < 0 || colorsScratchOffset < 0 || uvsScratchOffset < 0 || indicesScratchOffset < 0) {
            return false;
        }

        if (scratchGeneration != memoryGeneration) {
            scratchGeneration = memoryGeneration;
            var buf = memoryBuffer;
            vertsScratchView = new Float32Array(buf, vertsScratchOffset, vertsScratchFloats);
            colorsScratchView = new Float32Array(buf, colorsScratchOffset, colorsScratchFloats);
            packedScratchView = new Uint32Array(buf, colorsScratchOffset, colorsScratchFloats);
            uvsScratchView = new Float32Array(buf, uvsScratchOffset, uvsScratchFloats);
            indicesScratchView = new Int32Array(buf, indicesScratchOffset, indicesScratchInts);
        }

        return true;

    }

    static inline function nextPow2(v:Int):Int {
        var p = 1024;
        while (p < v) p <<= 1;
        return p;
    }

    /** Scratch views (valid after `requireScratch`, until the next memory growth). */
    public static var vertsScratch(get, never):Float32Array;
    inline static function get_vertsScratch():Float32Array return vertsScratchView;
    public static var colorsScratch(get, never):Float32Array;
    inline static function get_colorsScratch():Float32Array return colorsScratchView;
    public static var packedScratch(get, never):Uint32Array;
    inline static function get_packedScratch():Uint32Array return packedScratchView;
    public static var uvsScratch(get, never):Float32Array;
    inline static function get_uvsScratch():Float32Array return uvsScratchView;
    public static var indicesScratch(get, never):Int32Array;
    inline static function get_indicesScratch():Int32Array return indicesScratchView;

    /** Scratch byte offsets (stable across growth). */
    public static var vertsScratchByteOffset(get, never):Int;
    inline static function get_vertsScratchByteOffset():Int return vertsScratchOffset;
    public static var colorsScratchByteOffset(get, never):Int;
    inline static function get_colorsScratchByteOffset():Int return colorsScratchOffset;
    public static var uvsScratchByteOffset(get, never):Int;
    inline static function get_uvsScratchByteOffset():Int return uvsScratchOffset;
    public static var indicesScratchByteOffset(get, never):Int;
    inline static function get_indicesScratchByteOffset():Int return indicesScratchOffset;

    /**
     * Runs the fused mesh-part kernel. All offsets are byte offsets into
     * the module memory; see kernel.c for parameter semantics.
     */
    public static inline function meshPartF32(
        posByteOffset:Int, posStride:Int,
        colByteOffset:Int,
        uvByteOffset:Int,
        idxByteOffset:Int, idxBase:Int,
        vertsByteOffset:Int, vertStride:Int,
        floatColorsByteOffset:Int,
        packedColorsByteOffset:Int,
        uvsByteOffset:Int,
        indicesByteOffset:Int, start:Int, end:Int,
        a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float,
        z:Float, textureSlot:Float, writeSlot:Bool,
        colorMode:Int, singleR:Float, singleG:Float, singleB:Float, singleA:Float,
        globalAlpha:Float, premultiply:Bool, zeroAlpha:Bool,
        hasUvs:Bool, ufx:Float, ufy:Float,
        srcAttrCount:Int, dstAttrCount:Int
    ):Void {

        meshPartF32Fn(
            posByteOffset, posStride,
            colByteOffset,
            uvByteOffset,
            idxByteOffset, idxBase,
            vertsByteOffset, vertStride,
            floatColorsByteOffset,
            packedColorsByteOffset,
            uvsByteOffset,
            indicesByteOffset, start, end,
            a, b, c, d, tx, ty,
            z, textureSlot, writeSlot ? 1 : 0,
            colorMode, singleR, singleG, singleB, singleA,
            globalAlpha, premultiply ? 1 : 0, zeroAlpha ? 1 : 0,
            hasUvs ? 1 : 0, ufx, ufy,
            srcAttrCount, dstAttrCount
        );

    }

}

#end
