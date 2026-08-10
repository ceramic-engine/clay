#include "./linc_simd.h"

// Implementation selection. LINC_SIMD_FORCE_SCALAR (set via the build
// define `linc_simd_force_scalar`) compiles the plain C++ path on every
// architecture, which is useful to measure how much of the gain comes
// from batching alone versus vectorization.
#if !defined(LINC_SIMD_FORCE_SCALAR)
    #if defined(__ARM_NEON) || defined(__ARM_NEON__)
        #define LINC_SIMD_NEON 1
        #include <arm_neon.h>
    #elif defined(__SSE2__) || defined(_M_X64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
        #define LINC_SIMD_SSE2 1
        #include <emmintrin.h>
    #endif
#endif

#include <cstddef>

namespace {

    // Shared implementation for both source precisions. The gathered
    // loads are scalar (indexed access cannot be vectorized without
    // AVX2+/SVE gathers); the transform math and the stores are
    // vectorized 4 points at a time.
    //
    // Arithmetic order matters: ((tx + a*x) + c*y) reproduces the
    // left-associated scalar expression, and mul/add stay separate
    // (no fused multiply-add) so results match the scalar fallback.
    //
    // HASATTRS specializes the version copying interleaved custom float
    // attributes (source vertex [x y attr0..attrN] -> written vertex
    // [x y z (slot) attr0..attrM], zero-padded), keeping the common
    // attribute-less path free of any extra per-vertex work.
    template<typename T, bool HASATTRS>
    static void transformAffineIndexedImpl(
        float* dst, int dstStride,
        const T* verts, int vertStride,
        const int* indices, int count,
        float a, float b, float c, float d, float tx, float ty,
        float z, float slot, bool writeSlot,
        int srcAttrCount, int dstAttrCount) {

        int i = 0;

    #if defined(LINC_SIMD_NEON)
        float32x4_t va = vdupq_n_f32(a);
        float32x4_t vb = vdupq_n_f32(b);
        float32x4_t vc = vdupq_n_f32(c);
        float32x4_t vd = vdupq_n_f32(d);
        float32x4_t vtx = vdupq_n_f32(tx);
        float32x4_t vty = vdupq_n_f32(ty);
        float xs[4], ys[4], rx[4], ry[4];
        const T* vp[4];
        for (; i + 4 <= count; i += 4) {
            for (int k = 0; k < 4; k++) {
                const T* v = verts + (size_t)indices[i + k] * (size_t)vertStride;
                if (HASATTRS) vp[k] = v;
                xs[k] = (float)v[0];
                ys[k] = (float)v[1];
            }
            float32x4_t vx = vld1q_f32(xs);
            float32x4_t vy = vld1q_f32(ys);
            float32x4_t vrx = vaddq_f32(vaddq_f32(vtx, vmulq_f32(va, vx)), vmulq_f32(vc, vy));
            float32x4_t vry = vaddq_f32(vaddq_f32(vty, vmulq_f32(vb, vx)), vmulq_f32(vd, vy));
            vst1q_f32(rx, vrx);
            vst1q_f32(ry, vry);
            float* o = dst + (size_t)i * (size_t)dstStride;
            for (int k = 0; k < 4; k++) {
                o[0] = rx[k]; o[1] = ry[k]; o[2] = z;
                int base = 3;
                if (writeSlot) { o[3] = slot; base = 4; }
                if (HASATTRS) {
                    for (int n = 0; n < dstAttrCount; n++) {
                        o[base + n] = n < srcAttrCount ? (float)vp[k][2 + n] : 0.0f;
                    }
                }
                o += dstStride;
            }
        }
    #elif defined(LINC_SIMD_SSE2)
        __m128 va = _mm_set1_ps(a);
        __m128 vb = _mm_set1_ps(b);
        __m128 vc = _mm_set1_ps(c);
        __m128 vd = _mm_set1_ps(d);
        __m128 vtx = _mm_set1_ps(tx);
        __m128 vty = _mm_set1_ps(ty);
        float xs[4], ys[4], rx[4], ry[4];
        const T* vp[4];
        for (; i + 4 <= count; i += 4) {
            for (int k = 0; k < 4; k++) {
                const T* v = verts + (size_t)indices[i + k] * (size_t)vertStride;
                if (HASATTRS) vp[k] = v;
                xs[k] = (float)v[0];
                ys[k] = (float)v[1];
            }
            __m128 vx = _mm_loadu_ps(xs);
            __m128 vy = _mm_loadu_ps(ys);
            __m128 vrx = _mm_add_ps(_mm_add_ps(vtx, _mm_mul_ps(va, vx)), _mm_mul_ps(vc, vy));
            __m128 vry = _mm_add_ps(_mm_add_ps(vty, _mm_mul_ps(vb, vx)), _mm_mul_ps(vd, vy));
            _mm_storeu_ps(rx, vrx);
            _mm_storeu_ps(ry, vry);
            float* o = dst + (size_t)i * (size_t)dstStride;
            for (int k = 0; k < 4; k++) {
                o[0] = rx[k]; o[1] = ry[k]; o[2] = z;
                int base = 3;
                if (writeSlot) { o[3] = slot; base = 4; }
                if (HASATTRS) {
                    for (int n = 0; n < dstAttrCount; n++) {
                        o[base + n] = n < srcAttrCount ? (float)vp[k][2 + n] : 0.0f;
                    }
                }
                o += dstStride;
            }
        }
    #endif

        // Scalar fallback / tail
        for (; i < count; i++) {
            const T* v = verts + (size_t)indices[i] * (size_t)vertStride;
            float x = (float)v[0];
            float y = (float)v[1];
            float* o = dst + (size_t)i * (size_t)dstStride;
            o[0] = (tx + a * x) + c * y;
            o[1] = (ty + b * x) + d * y;
            o[2] = z;
            int base = 3;
            if (writeSlot) { o[3] = slot; base = 4; }
            if (HASATTRS) {
                for (int n = 0; n < dstAttrCount; n++) {
                    o[base + n] = n < srcAttrCount ? (float)v[2 + n] : 0.0f;
                }
            }
        }

    }

    static inline void premultiplyOneScalar(
        float* o, const float* s,
        float globalAlpha, bool premultiply, bool zeroAlpha) {

        float outA = globalAlpha * s[3];
        if (premultiply) {
            o[0] = s[0] * outA;
            o[1] = s[1] * outA;
            o[2] = s[2] * outA;
        }
        else {
            o[0] = s[0];
            o[1] = s[1];
            o[2] = s[2];
        }
        o[3] = zeroAlpha ? 0.0f : outA;

    }

}

namespace linc {

    namespace simd {

        int mode() {
        #if defined(LINC_SIMD_NEON)
            return 2;
        #elif defined(LINC_SIMD_SSE2)
            return 1;
        #else
            return 0;
        #endif
        }

        void transformAffineIndexedF32(
            float* dst, int dstStrideFloats,
            const float* verts, int vertStrideFloats,
            const int* indices, int indexCount,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot) {

            transformAffineIndexedImpl<float, false>(
                dst, dstStrideFloats, verts, vertStrideFloats, indices, indexCount,
                a, b, c, d, tx, ty, z, textureSlot, writeSlot, 0, 0);

        }

        void transformAffineIndexedF64(
            float* dst, int dstStrideFloats,
            const double* verts, int vertStrideFloats,
            const int* indices, int indexCount,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot) {

            transformAffineIndexedImpl<double, false>(
                dst, dstStrideFloats, verts, vertStrideFloats, indices, indexCount,
                a, b, c, d, tx, ty, z, textureSlot, writeSlot, 0, 0);

        }

        void transformAffineIndexedAttrsF32(
            float* dst, int dstStrideFloats,
            const float* verts, int vertStrideFloats,
            const int* indices, int indexCount,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot,
            int srcAttrCount, int dstAttrCount) {

            transformAffineIndexedImpl<float, true>(
                dst, dstStrideFloats, verts, vertStrideFloats, indices, indexCount,
                a, b, c, d, tx, ty, z, textureSlot, writeSlot, srcAttrCount, dstAttrCount);

        }

        void transformAffineIndexedAttrsF64(
            float* dst, int dstStrideFloats,
            const double* verts, int vertStrideFloats,
            const int* indices, int indexCount,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot,
            int srcAttrCount, int dstAttrCount) {

            transformAffineIndexedImpl<double, true>(
                dst, dstStrideFloats, verts, vertStrideFloats, indices, indexCount,
                a, b, c, d, tx, ty, z, textureSlot, writeSlot, srcAttrCount, dstAttrCount);

        }

        void transformQuadCorners(
            float* dst, int dstStrideFloats,
            float w, float h,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot, bool flipOrder) {

        #if defined(LINC_SIMD_NEON) || defined(LINC_SIMD_SSE2)

            // The 4 corner (x,y) pairs of the rectangle, in emission order
            float xs4[4], ys4[4], rx[4], ry[4];
            if (flipOrder) {
                // br, bl, tl, tr
                xs4[0] = w; xs4[1] = 0.0f; xs4[2] = 0.0f; xs4[3] = w;
                ys4[0] = h; ys4[1] = h;    ys4[2] = 0.0f; ys4[3] = 0.0f;
            }
            else {
                // tl, tr, br, bl
                xs4[0] = 0.0f; xs4[1] = w; xs4[2] = w; xs4[3] = 0.0f;
                ys4[0] = 0.0f; ys4[1] = 0.0f; ys4[2] = h; ys4[3] = h;
            }

            #if defined(LINC_SIMD_NEON)
            float32x4_t vx = vld1q_f32(xs4);
            float32x4_t vy = vld1q_f32(ys4);
            float32x4_t vrx = vaddq_f32(vaddq_f32(vdupq_n_f32(tx), vmulq_f32(vdupq_n_f32(a), vx)), vmulq_f32(vdupq_n_f32(c), vy));
            float32x4_t vry = vaddq_f32(vaddq_f32(vdupq_n_f32(ty), vmulq_f32(vdupq_n_f32(b), vx)), vmulq_f32(vdupq_n_f32(d), vy));
            vst1q_f32(rx, vrx);
            vst1q_f32(ry, vry);
            #else
            __m128 vx = _mm_loadu_ps(xs4);
            __m128 vy = _mm_loadu_ps(ys4);
            __m128 vrx = _mm_add_ps(_mm_add_ps(_mm_set1_ps(tx), _mm_mul_ps(_mm_set1_ps(a), vx)), _mm_mul_ps(_mm_set1_ps(c), vy));
            __m128 vry = _mm_add_ps(_mm_add_ps(_mm_set1_ps(ty), _mm_mul_ps(_mm_set1_ps(b), vx)), _mm_mul_ps(_mm_set1_ps(d), vy));
            _mm_storeu_ps(rx, vrx);
            _mm_storeu_ps(ry, vry);
            #endif

            float* o = dst;
            if (writeSlot) {
                for (int k = 0; k < 4; k++) { o[0] = rx[k]; o[1] = ry[k]; o[2] = z; o[3] = textureSlot; o += dstStrideFloats; }
            }
            else {
                for (int k = 0; k < 4; k++) { o[0] = rx[k]; o[1] = ry[k]; o[2] = z; o += dstStrideFloats; }
            }

        #else

            // Scalar fallback, same emission order and arithmetic order
            float xs4[4], ys4[4];
            if (flipOrder) {
                xs4[0] = w; xs4[1] = 0.0f; xs4[2] = 0.0f; xs4[3] = w;
                ys4[0] = h; ys4[1] = h;    ys4[2] = 0.0f; ys4[3] = 0.0f;
            }
            else {
                xs4[0] = 0.0f; xs4[1] = w; xs4[2] = w; xs4[3] = 0.0f;
                ys4[0] = 0.0f; ys4[1] = 0.0f; ys4[2] = h; ys4[3] = h;
            }
            float* o = dst;
            for (int k = 0; k < 4; k++) {
                float x = xs4[k];
                float y = ys4[k];
                o[0] = (tx + a * x) + c * y;
                o[1] = (ty + b * x) + d * y;
                o[2] = z;
                if (writeSlot) o[3] = textureSlot;
                o += dstStrideFloats;
            }

        #endif

        }

        void scaleUVIndexedF64(
            float* dst,
            const double* uvs, const int* indices, int indexCount,
            double uvFactorX, double uvFactorY) {

            int i = 0;

        #if defined(LINC_SIMD_NEON) && defined(__aarch64__)
            float64x2_t vf = { uvFactorX, uvFactorY };
            for (; i < indexCount; i++) {
                const double* uv = uvs + (size_t)indices[i] * 2;
                float64x2_t vuv = vld1q_f64(uv);
                float32x2_t vout = vcvt_f32_f64(vmulq_f64(vuv, vf));
                vst1_f32(dst + (size_t)i * 2, vout);
            }
        #elif defined(LINC_SIMD_SSE2)
            __m128d vf = _mm_set_pd(uvFactorY, uvFactorX);
            for (; i < indexCount; i++) {
                const double* uv = uvs + (size_t)indices[i] * 2;
                __m128d vuv = _mm_loadu_pd(uv);
                __m128 vout = _mm_cvtpd_ps(_mm_mul_pd(vuv, vf));
                _mm_storel_pi((__m64*)(dst + (size_t)i * 2), vout);
            }
        #else
            for (; i < indexCount; i++) {
                const double* uv = uvs + (size_t)indices[i] * 2;
                float* o = dst + (size_t)i * 2;
                o[0] = (float)(uv[0] * uvFactorX);
                o[1] = (float)(uv[1] * uvFactorY);
            }
        #endif

        }

        void premultiplyRGBA(
            float* dst,
            const float* src, int count,
            float globalAlpha, bool premultiply, bool zeroAlpha) {

            int i = 0;

        #if defined(LINC_SIMD_NEON)
            float alphaLane = zeroAlpha ? 0.0f : 1.0f;
            for (; i < count; i++) {
                float32x4_t v = vld1q_f32(src + (size_t)i * 4);
                float outA = globalAlpha * vgetq_lane_f32(v, 3);
                float rgbFactor = premultiply ? outA : 1.0f;
                // out = [r g b a] * [f f f ga] with the alpha lane optionally zeroed
                float32x4_t f = { rgbFactor, rgbFactor, rgbFactor, globalAlpha * alphaLane };
                vst1q_f32(dst + (size_t)i * 4, vmulq_f32(v, f));
            }
        #elif defined(LINC_SIMD_SSE2)
            float alphaLane = zeroAlpha ? 0.0f : 1.0f;
            for (; i < count; i++) {
                __m128 v = _mm_loadu_ps(src + (size_t)i * 4);
                float srcA;
                _mm_store_ss(&srcA, _mm_shuffle_ps(v, v, _MM_SHUFFLE(3, 3, 3, 3)));
                float outA = globalAlpha * srcA;
                float rgbFactor = premultiply ? outA : 1.0f;
                __m128 f = _mm_set_ps(globalAlpha * alphaLane, rgbFactor, rgbFactor, rgbFactor);
                _mm_storeu_ps(dst + (size_t)i * 4, _mm_mul_ps(v, f));
            }
        #else
            for (; i < count; i++) {
                premultiplyOneScalar(dst + (size_t)i * 4, src + (size_t)i * 4, globalAlpha, premultiply, zeroAlpha);
            }
        #endif

        }

        void premultiplyRGBAIndexed(
            float* dst,
            const float* src, const int* indices, int indexCount,
            float globalAlpha, bool premultiply, bool zeroAlpha) {

            int i = 0;

        #if defined(LINC_SIMD_NEON)
            float alphaLane = zeroAlpha ? 0.0f : 1.0f;
            for (; i < indexCount; i++) {
                float32x4_t v = vld1q_f32(src + (size_t)indices[i] * 4);
                float outA = globalAlpha * vgetq_lane_f32(v, 3);
                float rgbFactor = premultiply ? outA : 1.0f;
                float32x4_t f = { rgbFactor, rgbFactor, rgbFactor, globalAlpha * alphaLane };
                vst1q_f32(dst + (size_t)i * 4, vmulq_f32(v, f));
            }
        #elif defined(LINC_SIMD_SSE2)
            float alphaLane = zeroAlpha ? 0.0f : 1.0f;
            for (; i < indexCount; i++) {
                __m128 v = _mm_loadu_ps(src + (size_t)indices[i] * 4);
                float srcA;
                _mm_store_ss(&srcA, _mm_shuffle_ps(v, v, _MM_SHUFFLE(3, 3, 3, 3)));
                float outA = globalAlpha * srcA;
                float rgbFactor = premultiply ? outA : 1.0f;
                __m128 f = _mm_set_ps(globalAlpha * alphaLane, rgbFactor, rgbFactor, rgbFactor);
                _mm_storeu_ps(dst + (size_t)i * 4, _mm_mul_ps(v, f));
            }
        #else
            for (; i < indexCount; i++) {
                premultiplyOneScalar(dst + (size_t)i * 4, src + (size_t)indices[i] * 4, globalAlpha, premultiply, zeroAlpha);
            }
        #endif

        }

        void premultiplyARGB32(
            float* dst,
            const unsigned int* src, int count,
            float globalAlpha, bool premultiply, bool zeroAlpha) {

            int i = 0;
            const float inv255 = 1.0f / 255.0f;

        #if defined(LINC_SIMD_NEON)
            float32x4_t vinv255 = vdupq_n_f32(inv255);
            float32x4_t vga = vdupq_n_f32(globalAlpha);
            uint32x4_t vmask = vdupq_n_u32(0xFF);
            for (; i + 4 <= count; i += 4) {
                uint32x4_t cc = vld1q_u32(src + i);
                // decode 4 colors: 4 channel vectors, one lane per color
                float32x4_t r = vmulq_f32(vcvtq_f32_u32(vandq_u32(vshrq_n_u32(cc, 16), vmask)), vinv255);
                float32x4_t g = vmulq_f32(vcvtq_f32_u32(vandq_u32(vshrq_n_u32(cc, 8), vmask)), vinv255);
                float32x4_t b = vmulq_f32(vcvtq_f32_u32(vandq_u32(cc, vmask)), vinv255);
                float32x4_t outA = vmulq_f32(vga, vmulq_f32(vcvtq_f32_u32(vshrq_n_u32(cc, 24)), vinv255));
                if (premultiply) {
                    r = vmulq_f32(r, outA);
                    g = vmulq_f32(g, outA);
                    b = vmulq_f32(b, outA);
                }
                float32x4x4_t out;
                out.val[0] = r;
                out.val[1] = g;
                out.val[2] = b;
                out.val[3] = zeroAlpha ? vdupq_n_f32(0.0f) : outA;
                // interleaved store: r0 g0 b0 a0 r1 g1 b1 a1 ...
                vst4q_f32(dst + (size_t)i * 4, out);
            }
        #elif defined(LINC_SIMD_SSE2)
            __m128 vinv255 = _mm_set1_ps(inv255);
            __m128 vga = _mm_set1_ps(globalAlpha);
            __m128i vmask = _mm_set1_epi32(0xFF);
            for (; i + 4 <= count; i += 4) {
                __m128i cc = _mm_loadu_si128((const __m128i*)(src + i));
                __m128 r = _mm_mul_ps(_mm_cvtepi32_ps(_mm_and_si128(_mm_srli_epi32(cc, 16), vmask)), vinv255);
                __m128 g = _mm_mul_ps(_mm_cvtepi32_ps(_mm_and_si128(_mm_srli_epi32(cc, 8), vmask)), vinv255);
                __m128 b = _mm_mul_ps(_mm_cvtepi32_ps(_mm_and_si128(cc, vmask)), vinv255);
                __m128 outA = _mm_mul_ps(vga, _mm_mul_ps(_mm_cvtepi32_ps(_mm_srli_epi32(cc, 24)), vinv255));
                if (premultiply) {
                    r = _mm_mul_ps(r, outA);
                    g = _mm_mul_ps(g, outA);
                    b = _mm_mul_ps(b, outA);
                }
                __m128 a4 = zeroAlpha ? _mm_setzero_ps() : outA;
                _MM_TRANSPOSE4_PS(r, g, b, a4);
                float* o = dst + (size_t)i * 4;
                _mm_storeu_ps(o, r);
                _mm_storeu_ps(o + 4, g);
                _mm_storeu_ps(o + 8, b);
                _mm_storeu_ps(o + 12, a4);
            }
        #endif

            for (; i < count; i++) {
                unsigned int cc = src[i];
                float outA = globalAlpha * ((float)((cc >> 24) & 0xFF) * inv255);
                float r = (float)((cc >> 16) & 0xFF) * inv255;
                float g = (float)((cc >> 8) & 0xFF) * inv255;
                float b = (float)(cc & 0xFF) * inv255;
                float* o = dst + (size_t)i * 4;
                if (premultiply) {
                    o[0] = r * outA; o[1] = g * outA; o[2] = b * outA;
                }
                else {
                    o[0] = r; o[1] = g; o[2] = b;
                }
                o[3] = zeroAlpha ? 0.0f : outA;
            }

        }

        void premultiplyARGB32Indexed(
            float* dst,
            const unsigned int* src, const int* indices, int indexCount,
            float globalAlpha, bool premultiply, bool zeroAlpha) {

            int i = 0;
            const float inv255 = 1.0f / 255.0f;

        #if defined(LINC_SIMD_NEON)
            float32x4_t vinv255 = vdupq_n_f32(inv255);
            float32x4_t vga = vdupq_n_f32(globalAlpha);
            uint32x4_t vmask = vdupq_n_u32(0xFF);
            unsigned int cols[4];
            for (; i + 4 <= indexCount; i += 4) {
                for (int k = 0; k < 4; k++) {
                    cols[k] = src[indices[i + k]];
                }
                uint32x4_t cc = vld1q_u32(cols);
                float32x4_t r = vmulq_f32(vcvtq_f32_u32(vandq_u32(vshrq_n_u32(cc, 16), vmask)), vinv255);
                float32x4_t g = vmulq_f32(vcvtq_f32_u32(vandq_u32(vshrq_n_u32(cc, 8), vmask)), vinv255);
                float32x4_t b = vmulq_f32(vcvtq_f32_u32(vandq_u32(cc, vmask)), vinv255);
                float32x4_t outA = vmulq_f32(vga, vmulq_f32(vcvtq_f32_u32(vshrq_n_u32(cc, 24)), vinv255));
                if (premultiply) {
                    r = vmulq_f32(r, outA);
                    g = vmulq_f32(g, outA);
                    b = vmulq_f32(b, outA);
                }
                float32x4x4_t out;
                out.val[0] = r;
                out.val[1] = g;
                out.val[2] = b;
                out.val[3] = zeroAlpha ? vdupq_n_f32(0.0f) : outA;
                vst4q_f32(dst + (size_t)i * 4, out);
            }
        #elif defined(LINC_SIMD_SSE2)
            __m128 vinv255 = _mm_set1_ps(inv255);
            __m128 vga = _mm_set1_ps(globalAlpha);
            __m128i vmask = _mm_set1_epi32(0xFF);
            for (; i + 4 <= indexCount; i += 4) {
                __m128i cc = _mm_set_epi32(
                    (int)src[indices[i + 3]], (int)src[indices[i + 2]],
                    (int)src[indices[i + 1]], (int)src[indices[i]]);
                __m128 r = _mm_mul_ps(_mm_cvtepi32_ps(_mm_and_si128(_mm_srli_epi32(cc, 16), vmask)), vinv255);
                __m128 g = _mm_mul_ps(_mm_cvtepi32_ps(_mm_and_si128(_mm_srli_epi32(cc, 8), vmask)), vinv255);
                __m128 b = _mm_mul_ps(_mm_cvtepi32_ps(_mm_and_si128(cc, vmask)), vinv255);
                __m128 outA = _mm_mul_ps(vga, _mm_mul_ps(_mm_cvtepi32_ps(_mm_srli_epi32(cc, 24)), vinv255));
                if (premultiply) {
                    r = _mm_mul_ps(r, outA);
                    g = _mm_mul_ps(g, outA);
                    b = _mm_mul_ps(b, outA);
                }
                __m128 a4 = zeroAlpha ? _mm_setzero_ps() : outA;
                _MM_TRANSPOSE4_PS(r, g, b, a4);
                float* o = dst + (size_t)i * 4;
                _mm_storeu_ps(o, r);
                _mm_storeu_ps(o + 4, g);
                _mm_storeu_ps(o + 8, b);
                _mm_storeu_ps(o + 12, a4);
            }
        #endif

            for (; i < indexCount; i++) {
                unsigned int cc = src[indices[i]];
                float outA = globalAlpha * ((float)((cc >> 24) & 0xFF) * inv255);
                float r = (float)((cc >> 16) & 0xFF) * inv255;
                float g = (float)((cc >> 8) & 0xFF) * inv255;
                float b = (float)(cc & 0xFF) * inv255;
                float* o = dst + (size_t)i * 4;
                if (premultiply) {
                    o[0] = r * outA; o[1] = g * outA; o[2] = b * outA;
                }
                else {
                    o[0] = r; o[1] = g; o[2] = b;
                }
                o[3] = zeroAlpha ? 0.0f : outA;
            }

        }

        void fillColorRGBA(
            float* dst, int count,
            float r, float g, float b, float a) {

            int i = 0;

        #if defined(LINC_SIMD_NEON)
            float rgba[4] = { r, g, b, a };
            float32x4_t v = vld1q_f32(rgba);
            for (; i < count; i++) {
                vst1q_f32(dst + (size_t)i * 4, v);
            }
        #elif defined(LINC_SIMD_SSE2)
            __m128 v = _mm_set_ps(a, b, g, r);
            for (; i < count; i++) {
                _mm_storeu_ps(dst + (size_t)i * 4, v);
            }
        #else
            for (; i < count; i++) {
                float* o = dst + (size_t)i * 4;
                o[0] = r; o[1] = g; o[2] = b; o[3] = a;
            }
        #endif

        }

        void fillFloats(
            float* dst, int count, float value) {

            int i = 0;

        #if defined(LINC_SIMD_NEON)
            float32x4_t v = vdupq_n_f32(value);
            for (; i + 4 <= count; i += 4) {
                vst1q_f32(dst + i, v);
            }
        #elif defined(LINC_SIMD_SSE2)
            __m128 v = _mm_set1_ps(value);
            for (; i + 4 <= count; i += 4) {
                _mm_storeu_ps(dst + i, v);
            }
        #endif

            for (; i < count; i++) {
                dst[i] = value;
            }

        }

        void fillIndicesSequentialU16(
            unsigned short* dst, int start, int count) {

            int i = 0;

        #if defined(LINC_SIMD_NEON)
            unsigned short lane8[8] = { 0, 1, 2, 3, 4, 5, 6, 7 };
            uint16x8_t lane = vld1q_u16(lane8);
            // no loop-carried dependency: each store derives from the counter
            for (; i + 8 <= count; i += 8) {
                vst1q_u16(dst + i, vaddq_u16(vdupq_n_u16((unsigned short)(start + i)), lane));
            }
        #elif defined(LINC_SIMD_SSE2)
            __m128i lane = _mm_set_epi16(7, 6, 5, 4, 3, 2, 1, 0);
            // no loop-carried dependency: each store derives from the counter
            for (; i + 8 <= count; i += 8) {
                _mm_storeu_si128((__m128i*)(dst + i), _mm_add_epi16(_mm_set1_epi16((short)(start + i)), lane));
            }
        #endif

            for (; i < count; i++) {
                dst[i] = (unsigned short)(start + i);
            }

        }

        void putQuadIndicesU16(
            unsigned short* dst, int base) {

            unsigned short b0 = (unsigned short)base;
            dst[0] = b0;
            dst[1] = (unsigned short)(base + 1);
            dst[2] = (unsigned short)(base + 2);
            dst[3] = b0;
            dst[4] = (unsigned short)(base + 2);
            dst[5] = (unsigned short)(base + 3);

        }

        void emitQuad(
            float* pos, int posStrideFloats,
            unsigned short* idx, int indexBase,
            float* color, float* uv,
            float w, float h,
            float a, float b, float c, float d, float tx, float ty,
            float z, float textureSlot, bool writeSlot, bool flipOrder, bool wireframe,
            float colR, float colG, float colB, float colA,
            float u0, float v0, float u1, float v1,
            float u2, float v2, float u3, float v3) {

            if (wireframe) {
                putQuadWireframeIndicesU16(idx, indexBase);
            }
            else {
                putQuadIndicesU16(idx, indexBase);
            }

            transformQuadCorners(pos, posStrideFloats, w, h, a, b, c, d, tx, ty, z, textureSlot, writeSlot, flipOrder);

            fillColorRGBA(color, 4, colR, colG, colB, colA);

            storeUV4(uv, u0, v0, u1, v1, u2, v2, u3, v3);

        }

        void putQuadWireframeIndicesU16(
            unsigned short* dst, int base) {

            unsigned short b0 = (unsigned short)base;
            unsigned short b1 = (unsigned short)(base + 1);
            unsigned short b2 = (unsigned short)(base + 2);
            unsigned short b3 = (unsigned short)(base + 3);
            dst[0] = b0; dst[1] = b1;
            dst[2] = b1; dst[3] = b2;
            dst[4] = b2; dst[5] = b0;
            dst[6] = b0; dst[7] = b2;
            dst[8] = b2; dst[9] = b3;
            dst[10] = b3; dst[11] = b0;

        }

        void fillQuadAttrsF64(
            float* dst, int dstStrideFloats, int attrOffset,
            const double* attrs, int srcCount, int dstCount) {

            float* o = dst + attrOffset;
            for (int k = 0; k < 4; k++) {
                for (int n = 0; n < dstCount; n++) {
                    o[n] = n < srcCount ? (float)attrs[n] : 0.0f;
                }
                o += dstStrideFloats;
            }

        }

        void storeUV4(
            float* dst,
            float u0, float v0, float u1, float v1,
            float u2, float v2, float u3, float v3) {

        #if defined(LINC_SIMD_NEON)
            float uv[8] = { u0, v0, u1, v1, u2, v2, u3, v3 };
            vst1q_f32(dst, vld1q_f32(uv));
            vst1q_f32(dst + 4, vld1q_f32(uv + 4));
        #elif defined(LINC_SIMD_SSE2)
            _mm_storeu_ps(dst, _mm_set_ps(v1, u1, v0, u0));
            _mm_storeu_ps(dst + 4, _mm_set_ps(v3, u3, v2, u2));
        #else
            dst[0] = u0; dst[1] = v0;
            dst[2] = u1; dst[3] = v1;
            dst[4] = u2; dst[5] = v2;
            dst[6] = u3; dst[7] = v3;
        #endif

        }

    }

}
