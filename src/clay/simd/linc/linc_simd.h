#pragma once

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

// Batched geometry kernels operating on raw pointers.
//
// Contract with the caller (critical):
// - Every function is a leaf: it performs no allocation, no callback,
//   and never touches the haxe runtime. This guarantees that no GC
//   collection can happen while the provided pointers are in use
//   (hxcpp GC only runs at allocation points / safe points).
// - Pointers must be acquired right before the call and never cached.
// - `dst` pointers point at the current write cursor of the target
//   buffer; the caller advances its cursors after the call returns.
//
// Precision note: position and color kernels compute in 32-bit float
// (values are stored as 32-bit floats anyway). The historical scalar
// path computes intermediates in 64-bit before the final float store,
// so results can differ by ~1 ULP of the stored float. This is far
// below rasterization/quantization precision. UV scaling is done in
// 64-bit to match the scalar path exactly, as texture coordinates are
// the most precision-sensitive values (atlas edges).

namespace linc {

    namespace simd {

        // Which implementation was compiled in: 0 = scalar, 1 = SSE2, 2 = NEON
        extern int mode();

        // Transforms `indexCount` points gathered from `verts` via `indices`
        // with the 2x3 affine matrix (a,b,c,d,tx,ty), writing sequential
        // strided vertices [x y z (slot)] into `dst`.
        // `vertStrideFloats` is the distance in elements between two points
        // in `verts` (2 when there are no extra interleaved attributes).
        // F32 variant reads 32-bit float sources, F64 reads 64-bit sources.
        extern void transformAffineIndexedF32(
            float* dst, int dstStrideFloats,
            const float* verts, int vertStrideFloats,
            const int* indices, int indexCount,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot);

        extern void transformAffineIndexedF64(
            float* dst, int dstStrideFloats,
            const double* verts, int vertStrideFloats,
            const int* indices, int indexCount,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot);

        // Same as transformAffineIndexedF32/F64 for meshes carrying custom
        // float attributes interleaved with positions: each source vertex is
        // [x y attr0..attrN], each written vertex is
        // [x y z (slot) attr0..attrM] (missing attributes zero-padded when
        // the shader expects more than the mesh provides).
        extern void transformAffineIndexedAttrsF32(
            float* dst, int dstStrideFloats,
            const float* verts, int vertStrideFloats,
            const int* indices, int indexCount,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot,
            int srcAttrCount, int dstAttrCount);

        extern void transformAffineIndexedAttrsF64(
            float* dst, int dstStrideFloats,
            const double* verts, int vertStrideFloats,
            const int* indices, int indexCount,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot,
            int srcAttrCount, int dstAttrCount);

        // Transforms the 4 corners of a (w,h) rectangle with the 2x3 affine
        // matrix and writes 4 strided vertices [x y z (slot)] into `dst`.
        // Corner order: flipOrder=true -> br, bl, tl, tr ; false -> tl, tr, br, bl.
        extern void transformQuadCorners(
            float* dst, int dstStrideFloats,
            float w, float h,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot, bool flipOrder);

        // Gathers `indexCount` UV pairs from `uvs` (64-bit source, stride 2)
        // via `indices`, multiplies by (uvFactorX, uvFactorY) in 64-bit and
        // writes sequential 32-bit pairs into `dst`.
        extern void scaleUVIndexedF64(
            float* dst,
            const double* uvs, const int* indices, int indexCount,
            double uvFactorX, double uvFactorY);

        // Reads `count` sequential RGBA colors from `src`, computes
        // outA = globalAlpha * srcA, multiplies RGB by outA when
        // `premultiply` is set, forces the stored alpha to 0 when
        // `zeroAlpha` is set (RGB keep the premultiplied values), and
        // writes sequential RGBA into `dst`.
        extern void premultiplyRGBA(
            float* dst,
            const float* src, int count,
            float globalAlpha, bool premultiply, bool zeroAlpha);

        // Same as premultiplyRGBA but colors are gathered from `src`
        // via `indices` (one RGBA per index).
        extern void premultiplyRGBAIndexed(
            float* dst,
            const float* src, const int* indices, int indexCount,
            float globalAlpha, bool premultiply, bool zeroAlpha);

        // Same as premultiplyRGBA but the source colors are packed 32-bit
        // integers laid out as 0xAARRGGBB. Channels are decoded to floats
        // in [0,1] (x * 1/255) before the same premultiply logic.
        extern void premultiplyARGB32(
            float* dst,
            const unsigned int* src, int count,
            float globalAlpha, bool premultiply, bool zeroAlpha);

        // Same as premultiplyARGB32 but colors are gathered from `src`
        // via `indices` (one packed color per index).
        extern void premultiplyARGB32Indexed(
            float* dst,
            const unsigned int* src, const int* indices, int indexCount,
            float globalAlpha, bool premultiply, bool zeroAlpha);

        // Writes `count` copies of the RGBA color into `dst`.
        extern void fillColorRGBA(
            float* dst, int count,
            float r, float g, float b, float a);

        // Writes `count` copies of `value` into `dst`.
        extern void fillFloats(
            float* dst, int count, float value);

        // Writes count sequential indices start, start+1, ... into `dst`.
        extern void fillIndicesSequentialU16(
            unsigned short* dst, int start, int count);

        // Writes the 6 indices of a quad (two triangles):
        // base, base+1, base+2, base, base+2, base+3.
        extern void putQuadIndicesU16(
            unsigned short* dst, int base);

        // Writes the 12 line indices of a quad wireframe:
        // (b,b+1),(b+1,b+2),(b+2,b),(b,b+2),(b+2,b+3),(b+3,b).
        extern void putQuadWireframeIndicesU16(
            unsigned short* dst, int base);

        // Writes the same attribute values on the 4 corners of a quad,
        // at `attrOffset` floats inside each vertex of stride
        // `dstStrideFloats`. Reads `srcCount` values from `attrs`
        // (64-bit source, may be null when srcCount is 0), zero-pads
        // up to `dstCount`.
        extern void fillQuadAttrsF64(
            float* dst, int dstStrideFloats, int attrOffset,
            const double* attrs, int srcCount, int dstCount);

        // Emits a complete quad in a single call: indices (6 triangle
        // indices, or 12 line indices when `wireframe` is set), 4
        // transformed corners, 4 identical colors and 4 uv pairs.
        // Fusing everything in one call matters here: a quad is a tiny
        // amount of work, so per-call overhead would otherwise dominate.
        extern void emitQuad(
            float* pos, int posStrideFloats,
            unsigned short* idx, int indexBase,
            float* color, float* uv,
            float w, float h,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot, bool flipOrder, bool wireframe,
            float colR, float colG, float colB, float colA,
            float u0, float v0, float u1, float v1,
            float u2, float v2, float u3, float v3);

        // Writes 4 finished UV pairs into `dst` (8 contiguous floats).
        extern void storeUV4(
            float* dst,
            float u0, float v0, float u1, float v1,
            float u2, float v2, float u3, float v3);

    }

}
