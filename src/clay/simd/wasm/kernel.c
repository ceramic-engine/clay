// Fused mesh-part emission kernel for the web target (wasm).
//
// One call per mesh part: gathers positions/colors/uvs through the index
// array, transforms and writes full vertices into the staging buffers
// (separate pos/color/uv/index arrays, same layout as the GL batcher).
// Sources are copied by the caller into wasm scratch regions before the
// call (typed-array .set copies are nearly free browser-side); the staging
// destinations are views over this module's memory, so gl.bufferData
// uploads with zero extra copies.
//
// Built twice by build.sh: with -msimd128 (wasm SIMD, ~all browsers since
// 2021/2023) and without (plain wasm fallback). Semantics are strictly
// deterministic (no relaxed SIMD, no FMA).
//
// Color modes:
//   0 = single color (r,g,b,a params, already resolved by the caller)
//   1 = float colors, sequential per index (colorMapping INDICES)
//   2 = float colors, gathered per vertex (colorMapping VERTICES)
//   3 = packed 0xAARRGGBB colors, sequential per index
//   4 = packed 0xAARRGGBB colors, gathered per vertex

#include <stdint.h>

#ifdef __wasm_simd128__
#include <wasm_simd128.h>
#endif

#define KEEPALIVE __attribute__((used, visibility("default")))

static inline void writeColor(
    float* co, float srcR, float srcG, float srcB, float srcA,
    float globalAlpha, int premultiply, int zeroAlpha) {

    float outA = globalAlpha * srcA;
    if (premultiply) {
        co[0] = srcR * outA;
        co[1] = srcG * outA;
        co[2] = srcB * outA;
    }
    else {
        co[0] = srcR;
        co[1] = srcG;
        co[2] = srcB;
    }
    co[3] = zeroAlpha ? 0.0f : outA;

}

KEEPALIVE
void meshPartF32(
    float* pos, int posStride,
    float* col,
    float* uv,
    uint16_t* idxDst, int idxBase,
    const float* verts, int vertStride,
    const float* floatColors,
    const uint32_t* packedColors,
    const float* uvs,
    const int* indices, int start, int end,
    float a, float b, float c, float d, float tx, float ty,
    float z, float textureSlot, int writeSlot,
    int colorMode, float singleR, float singleG, float singleB, float singleA,
    float globalAlpha, int premultiply, int zeroAlpha,
    int hasUvs, float ufx, float ufy,
    int srcAttrCount, int dstAttrCount) {

    int count = end - start;
    int i = 0;

    // Sequential indices
    for (; i + 4 <= count; i += 4) {
        idxDst[i] = (uint16_t)(idxBase + i);
        idxDst[i + 1] = (uint16_t)(idxBase + i + 1);
        idxDst[i + 2] = (uint16_t)(idxBase + i + 2);
        idxDst[i + 3] = (uint16_t)(idxBase + i + 3);
    }
    for (; i < count; i++) {
        idxDst[i] = (uint16_t)(idxBase + i);
    }

    // Positions (+ interleaved custom attributes)
    i = 0;

#ifdef __wasm_simd128__
    if (srcAttrCount == 0 && dstAttrCount == 0) {
        v128_t va = wasm_f32x4_splat(a);
        v128_t vb = wasm_f32x4_splat(b);
        v128_t vc = wasm_f32x4_splat(c);
        v128_t vd = wasm_f32x4_splat(d);
        v128_t vtx = wasm_f32x4_splat(tx);
        v128_t vty = wasm_f32x4_splat(ty);
        float xs[4], ys[4], rx[4], ry[4];
        for (; i + 4 <= count; i += 4) {
            for (int k = 0; k < 4; k++) {
                const float* v = verts + (long)indices[start + i + k] * vertStride;
                xs[k] = v[0];
                ys[k] = v[1];
            }
            v128_t vx = wasm_v128_load(xs);
            v128_t vy = wasm_v128_load(ys);
            v128_t vrx = wasm_f32x4_add(wasm_f32x4_add(vtx, wasm_f32x4_mul(va, vx)), wasm_f32x4_mul(vc, vy));
            v128_t vry = wasm_f32x4_add(wasm_f32x4_add(vty, wasm_f32x4_mul(vb, vx)), wasm_f32x4_mul(vd, vy));
            wasm_v128_store(rx, vrx);
            wasm_v128_store(ry, vry);
            float* o = pos + (long)i * posStride;
            if (writeSlot) {
                for (int k = 0; k < 4; k++) { o[0] = rx[k]; o[1] = ry[k]; o[2] = z; o[3] = textureSlot; o += posStride; }
            }
            else {
                for (int k = 0; k < 4; k++) { o[0] = rx[k]; o[1] = ry[k]; o[2] = z; o += posStride; }
            }
        }
    }
#endif

    for (; i < count; i++) {
        const float* v = verts + (long)indices[start + i] * vertStride;
        float x = v[0];
        float y = v[1];
        float* o = pos + (long)i * posStride;
        o[0] = (tx + a * x) + c * y;
        o[1] = (ty + b * x) + d * y;
        o[2] = z;
        int attrBase = 3;
        if (writeSlot) { o[3] = textureSlot; attrBase = 4; }
        for (int n = 0; n < dstAttrCount; n++) {
            o[attrBase + n] = n < srcAttrCount ? v[2 + n] : 0.0f;
        }
    }

    // Colors
    switch (colorMode) {
        case 0: {
            i = 0;
        #ifdef __wasm_simd128__
            v128_t vcol = wasm_f32x4_make(singleR, singleG, singleB, singleA);
            for (; i < count; i++) {
                wasm_v128_store(col + (long)i * 4, vcol);
            }
        #else
            for (; i < count; i++) {
                float* co = col + (long)i * 4;
                co[0] = singleR; co[1] = singleG; co[2] = singleB; co[3] = singleA;
            }
        #endif
            break;
        }
        case 1:
        case 2: {
            for (i = 0; i < count; i++) {
                long src = (long)(colorMode == 1 ? (start + i) : indices[start + i]) * 4;
                writeColor(col + (long)i * 4,
                    floatColors[src], floatColors[src + 1], floatColors[src + 2], floatColors[src + 3],
                    globalAlpha, premultiply, zeroAlpha);
            }
            break;
        }
        default: {
            const float inv255 = 1.0f / 255.0f;
            for (i = 0; i < count; i++) {
                uint32_t pc = packedColors[colorMode == 3 ? (start + i) : indices[start + i]];
                writeColor(col + (long)i * 4,
                    (float)((pc >> 16) & 0xFF) * inv255,
                    (float)((pc >> 8) & 0xFF) * inv255,
                    (float)(pc & 0xFF) * inv255,
                    (float)((pc >> 24) & 0xFF) * inv255,
                    globalAlpha, premultiply, zeroAlpha);
            }
            break;
        }
    }

    // UVs
    if (hasUvs) {
        i = 0;
    #ifdef __wasm_simd128__
        v128_t vf = wasm_f32x4_make(ufx, ufy, ufx, ufy);
        for (; i + 2 <= count; i += 2) {
            const float* u0 = uvs + (long)indices[start + i] * 2;
            const float* u1 = uvs + (long)indices[start + i + 1] * 2;
            v128_t vu = wasm_f32x4_make(u0[0], u0[1], u1[0], u1[1]);
            wasm_v128_store(uv + (long)i * 2, wasm_f32x4_mul(vu, vf));
        }
    #endif
        for (; i < count; i++) {
            const float* us = uvs + (long)indices[start + i] * 2;
            uv[(long)i * 2] = us[0] * ufx;
            uv[(long)i * 2 + 1] = us[1] * ufy;
        }
    }
    else {
        for (i = 0; i < count; i++) {
            uv[(long)i * 2] = 0.0f;
            uv[(long)i * 2 + 1] = 0.0f;
        }
    }

}
