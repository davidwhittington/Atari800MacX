/*
 * Shaders.metal — Atari800MacX Phase 5 Metal renderer
 *                 Phase B: linear filter + variable scanline transparency
 *
 * emulatorVertex : fullscreen quad driven by a packed NDC rect uniform
 * emulatorFragment: switchable nearest/linear texture sample +
 *                   optional CRT scanline darkening with configurable transparency
 */

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct FragParams {
    int   scanlines;            /* non-zero → apply scanline effect */
    float scanlineTransparency; /* 0.0 = fully dark, 1.0 = fully bright */
};

/*
 * quad : packed float4 { left, bottom, right, top } in NDC (-1 .. +1)
 *   Windowed mode          : { -1, -1,  1,  1 }  (fills entire drawable)
 *   Fullscreen letter-box  : computed by EmulatorMetalView from SDL window metrics
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
 * tex    : BGRA8Unorm texture containing the current Atari frame
 * smp    : sampler passed from CPU (nearest or linear depending on user pref)
 * params : FragParams — scanlines flag + scanline transparency
 */
fragment float4 emulatorFragment(VertexOut             in     [[stage_in]],
                                 texture2d<float>      tex    [[texture(0)]],
                                 sampler               smp    [[sampler(0)]],
                                 constant FragParams  &params [[buffer(0)]]) {
    float4 color = tex.sample(smp, in.uv);

    if (params.scanlines && fmod(floor(in.position.y), 2.0f) < 1.0f)
        color.rgb *= params.scanlineTransparency;

    return color;
}
