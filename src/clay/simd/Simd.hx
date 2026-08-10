package clay.simd;

#if cpp

import cpp.Float32;
import cpp.RawPointer;
import cpp.UInt16;

/**
 * Batched geometry kernels operating on raw pointers (native C++).
 *
 * Every function is a leaf call: no allocation, no callback into haxe,
 * so no GC collection can happen while the provided pointers are in use.
 * Callers must acquire pointers right before the call, keep the owning
 * haxe objects alive on the stack for the duration of the call, and
 * never cache raw pointers across calls.
 *
 * The vectorized implementations (SSE2 on x86, NEON on ARM) are picked
 * at compile time, with a plain C++ fallback. Define
 * `linc_simd_force_scalar` to force the plain C++ path everywhere
 * (useful to measure batching gains without vectorization).
 */
@:keep
#if !display
@:build(clay.simd.Linc.touch())
@:build(clay.simd.Linc.xml('simd', '../simd'))
#end
@:include('linc_simd.h')
extern class Simd {

    /** Which implementation was compiled in: 0 = scalar, 1 = SSE2, 2 = NEON */
    @:native('::linc::simd::mode')
    static function mode():Int;

    /**
     * Transforms `indexCount` points gathered from `verts` (32-bit floats)
     * via `indices` with the 2x3 affine matrix (a,b,c,d,tx,ty), writing
     * sequential strided vertices [x y z (slot)] into `dst`.
     */
    @:native('::linc::simd::transformAffineIndexedF32')
    static function transformAffineIndexedF32(
        dst:RawPointer<Float32>, dstStrideFloats:Int,
        verts:RawPointer<Float32>, vertStrideFloats:Int,
        indices:RawPointer<Int>, indexCount:Int,
        a:Float32, b:Float32, c:Float32, d:Float32, tx:Float32, ty:Float32,
        z:Float32, textureSlot:Float32, writeSlot:Bool):Void;

    /**
     * Same as `transformAffineIndexedF32` with a 64-bit float source
     * (haxe `Array<Float>` holds 64-bit values on this target).
     */
    @:native('::linc::simd::transformAffineIndexedF64')
    static function transformAffineIndexedF64(
        dst:RawPointer<Float32>, dstStrideFloats:Int,
        verts:RawPointer<Float>, vertStrideFloats:Int,
        indices:RawPointer<Int>, indexCount:Int,
        a:Float32, b:Float32, c:Float32, d:Float32, tx:Float32, ty:Float32,
        z:Float32, textureSlot:Float32, writeSlot:Bool):Void;

    /**
     * Same as `transformAffineIndexedF32` for meshes carrying custom float
     * attributes interleaved with positions ([x y attr0..attrN] source,
     * [x y z (slot) attr0..attrM] destination, zero-padded).
     */
    @:native('::linc::simd::transformAffineIndexedAttrsF32')
    static function transformAffineIndexedAttrsF32(
        dst:RawPointer<Float32>, dstStrideFloats:Int,
        verts:RawPointer<Float32>, vertStrideFloats:Int,
        indices:RawPointer<Int>, indexCount:Int,
        a:Float32, b:Float32, c:Float32, d:Float32, tx:Float32, ty:Float32,
        z:Float32, textureSlot:Float32, writeSlot:Bool,
        srcAttrCount:Int, dstAttrCount:Int):Void;

    /** Same as `transformAffineIndexedAttrsF32` with a 64-bit float source. */
    @:native('::linc::simd::transformAffineIndexedAttrsF64')
    static function transformAffineIndexedAttrsF64(
        dst:RawPointer<Float32>, dstStrideFloats:Int,
        verts:RawPointer<Float>, vertStrideFloats:Int,
        indices:RawPointer<Int>, indexCount:Int,
        a:Float32, b:Float32, c:Float32, d:Float32, tx:Float32, ty:Float32,
        z:Float32, textureSlot:Float32, writeSlot:Bool,
        srcAttrCount:Int, dstAttrCount:Int):Void;

    /**
     * Transforms the 4 corners of a (w,h) rectangle with the 2x3 affine
     * matrix and writes 4 strided vertices [x y z (slot)] into `dst`.
     * Corner order: flipOrder=true -> br, bl, tl, tr ; false -> tl, tr, br, bl.
     */
    @:native('::linc::simd::transformQuadCorners')
    static function transformQuadCorners(
        dst:RawPointer<Float32>, dstStrideFloats:Int,
        w:Float32, h:Float32,
        a:Float32, b:Float32, c:Float32, d:Float32, tx:Float32, ty:Float32,
        z:Float32, textureSlot:Float32, writeSlot:Bool, flipOrder:Bool):Void;

    /**
     * Gathers `indexCount` UV pairs from `uvs` (64-bit source, stride 2)
     * via `indices`, multiplies by (uvFactorX, uvFactorY) in 64-bit and
     * writes sequential 32-bit pairs into `dst`.
     */
    @:native('::linc::simd::scaleUVIndexedF64')
    static function scaleUVIndexedF64(
        dst:RawPointer<Float32>,
        uvs:RawPointer<Float>, indices:RawPointer<Int>, indexCount:Int,
        uvFactorX:Float, uvFactorY:Float):Void;

    /**
     * Reads `count` sequential RGBA colors from `src`, computes
     * outA = globalAlpha * srcA, multiplies RGB by outA when `premultiply`
     * is set, forces the stored alpha to 0 when `zeroAlpha` is set (RGB
     * keep the premultiplied values), and writes sequential RGBA into `dst`.
     */
    @:native('::linc::simd::premultiplyRGBA')
    static function premultiplyRGBA(
        dst:RawPointer<Float32>,
        src:RawPointer<Float32>, count:Int,
        globalAlpha:Float32, premultiply:Bool, zeroAlpha:Bool):Void;

    /** Same as `premultiplyRGBA` but colors are gathered from `src` via `indices`. */
    @:native('::linc::simd::premultiplyRGBAIndexed')
    static function premultiplyRGBAIndexed(
        dst:RawPointer<Float32>,
        src:RawPointer<Float32>, indices:RawPointer<Int>, indexCount:Int,
        globalAlpha:Float32, premultiply:Bool, zeroAlpha:Bool):Void;

    /**
     * Same as `premultiplyRGBA` but the source colors are packed 32-bit
     * integers laid out as 0xAARRGGBB, decoded to floats in [0,1].
     */
    @:native('::linc::simd::premultiplyARGB32')
    static function premultiplyARGB32(
        dst:RawPointer<Float32>,
        src:RawPointer<cpp.UInt32>, count:Int,
        globalAlpha:Float32, premultiply:Bool, zeroAlpha:Bool):Void;

    /** Same as `premultiplyARGB32` but colors are gathered from `src` via `indices`. */
    @:native('::linc::simd::premultiplyARGB32Indexed')
    static function premultiplyARGB32Indexed(
        dst:RawPointer<Float32>,
        src:RawPointer<cpp.UInt32>, indices:RawPointer<Int>, indexCount:Int,
        globalAlpha:Float32, premultiply:Bool, zeroAlpha:Bool):Void;

    /** Writes `count` copies of the RGBA color into `dst`. */
    @:native('::linc::simd::fillColorRGBA')
    static function fillColorRGBA(
        dst:RawPointer<Float32>, count:Int,
        r:Float32, g:Float32, b:Float32, a:Float32):Void;

    /** Writes `count` copies of `value` into `dst`. */
    @:native('::linc::simd::fillFloats')
    static function fillFloats(
        dst:RawPointer<Float32>, count:Int, value:Float32):Void;

    /** Writes `count` sequential indices start, start+1, ... into `dst`. */
    @:native('::linc::simd::fillIndicesSequentialU16')
    static function fillIndicesSequentialU16(
        dst:RawPointer<UInt16>, start:Int, count:Int):Void;

    /**
     * Writes the 6 indices of a quad (two triangles):
     * base, base+1, base+2, base, base+2, base+3.
     */
    @:native('::linc::simd::putQuadIndicesU16')
    static function putQuadIndicesU16(
        dst:RawPointer<UInt16>, base:Int):Void;

    /**
     * Writes the 12 line indices of a quad wireframe:
     * (b,b+1),(b+1,b+2),(b+2,b),(b,b+2),(b+2,b+3),(b+3,b).
     */
    @:native('::linc::simd::putQuadWireframeIndicesU16')
    static function putQuadWireframeIndicesU16(
        dst:RawPointer<UInt16>, base:Int):Void;

    /**
     * Writes the same attribute values on the 4 corners of a quad, at
     * `attrOffset` floats inside each vertex of stride `dstStrideFloats`,
     * reading `srcCount` values from `attrs` (may be null when 0) and
     * zero-padding up to `dstCount`.
     */
    @:native('::linc::simd::fillQuadAttrsF64')
    static function fillQuadAttrsF64(
        dst:RawPointer<Float32>, dstStrideFloats:Int, attrOffset:Int,
        attrs:RawPointer<Float>, srcCount:Int, dstCount:Int):Void;

    /**
     * Emits a complete quad in a single call: indices (6 triangle indices,
     * or 12 line indices when `wireframe` is set), 4 transformed corners,
     * 4 identical colors and 4 uv pairs. One call per quad keeps the
     * per-call overhead negligible compared to the quad's small workload.
     */
    @:native('::linc::simd::emitQuad')
    static function emitQuad(
        pos:RawPointer<Float32>, posStrideFloats:Int,
        idx:RawPointer<UInt16>, indexBase:Int,
        color:RawPointer<Float32>, uv:RawPointer<Float32>,
        w:Float32, h:Float32,
        a:Float32, b:Float32, c:Float32, d:Float32, tx:Float32, ty:Float32,
        z:Float32, textureSlot:Float32, writeSlot:Bool, flipOrder:Bool, wireframe:Bool,
        colR:Float32, colG:Float32, colB:Float32, colA:Float32,
        u0:Float32, v0:Float32, u1:Float32, v1:Float32,
        u2:Float32, v2:Float32, u3:Float32, v3:Float32):Void;

    /** Writes 4 finished UV pairs into `dst` (8 contiguous floats). */
    @:native('::linc::simd::storeUV4')
    static function storeUV4(
        dst:RawPointer<Float32>,
        u0:Float32, v0:Float32, u1:Float32, v1:Float32,
        u2:Float32, v2:Float32, u3:Float32, v3:Float32):Void;

}

#end
