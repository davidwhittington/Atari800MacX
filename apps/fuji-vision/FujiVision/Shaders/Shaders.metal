/*
 * Shaders.metal — Fuji-Vision Metal renderer
 *                 Shared with fuji-foundation (identical shader pair)
 *
 * emulatorVertex : fullscreen quad driven by a packed NDC rect uniform
 * emulatorFragment: switchable nearest/linear texture sample +
 *                   optional CRT scanline darkening, visibility alpha,
 *                   chroma key transparency, and edge enhancement
 */

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct FragParams {
    int   scanlines;            /* non-zero -> apply scanline effect */
    float scanlineTransparency; /* 0.0 = fully dark, 1.0 = fully bright */
    float globalAlpha;          /* 0.0–1.0, mode-driven, lerped */
    int   keyEnabled;           /* non-zero -> apply chroma key */
    float keyR, keyG, keyB;     /* key color (normalized 0–1) */
    float keyThreshold;         /* color distance tolerance */
    float keySoftEdge;          /* feathering width */
    int   keyInvert;            /* invert transparency */
    float edgeEnhance;          /* edge brightness boost (0 = off) */
};

/*
 * quad : packed float4 { left, bottom, right, top } in NDC (-1 .. +1)
 *
 * Triangle-strip vertex order (vid 0-3):
 *   0 = top-left   1 = top-right
 *   2 = bottom-left  3 = bottom-right
 */
vertex VertexOut emulatorVertex(uint vid [[vertex_id]],
                                constant float4 &quad [[buffer(0)]]) {
    const float2 pos[4] = {
        { quad.x, quad.w },   // top-left     (left,  top)
        { quad.z, quad.w },   // top-right    (right, top)
        { quad.x, quad.y },   // bottom-left  (left,  bottom)
        { quad.z, quad.y }    // bottom-right (right, bottom)
    };
    const float2 uv[4] = {
        { 0.0f, 0.0f },
        { 1.0f, 0.0f },
        { 0.0f, 1.0f },
        { 1.0f, 1.0f }
    };

    VertexOut out;
    out.position = float4(pos[vid], 0.0f, 1.0f);
    out.uv       = uv[vid];
    return out;
}

/*
 * tex    : RGBA8Unorm texture containing the current Atari frame
 * smp    : sampler passed from CPU (nearest or linear depending on user pref)
 * params : FragParams -- scanlines, visibility, chroma key, edge enhance
 */
fragment float4 emulatorFragment(VertexOut             in     [[stage_in]],
                                 texture2d<float>      tex    [[texture(0)]],
                                 sampler               smp    [[sampler(0)]],
                                 constant FragParams  &params [[buffer(0)]]) {
    float4 color = tex.sample(smp, in.uv);

    // CRT scanline darkening
    if (params.scanlines && fmod(floor(in.position.y), 2.0f) < 1.0f)
        color.rgb *= params.scanlineTransparency;

    // Compute output alpha from visibility mode
    float alpha = params.globalAlpha;

    // Chroma key transparency
    if (params.keyEnabled) {
        float3 keyColor = float3(params.keyR, params.keyG, params.keyB);
        float dist = distance(color.rgb, keyColor);
        float keyAlpha = smoothstep(params.keyThreshold,
                                     params.keyThreshold + params.keySoftEdge,
                                     dist);
        if (params.keyInvert) keyAlpha = 1.0 - keyAlpha;
        alpha *= keyAlpha;

        // Edge enhancement at key boundary
        if (params.edgeEnhance > 0.0) {
            float edgeFactor = 1.0 - abs(dist - params.keyThreshold)
                               / max(params.keySoftEdge, 0.001);
            edgeFactor = saturate(edgeFactor) * params.edgeEnhance;
            color.rgb += edgeFactor * 0.3;
        }
    }

    color.a = alpha;
    return color;
}
