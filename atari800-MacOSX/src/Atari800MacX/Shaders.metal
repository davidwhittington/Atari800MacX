/*
 * Shaders.metal — Atari800MacX Phase 5 Metal renderer
 *
 * emulatorVertex : fullscreen quad driven by a packed NDC rect uniform
 * emulatorFragment: nearest-filter texture sample + optional scanline darkening
 */

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
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
 * tex      : BGRA8Unorm texture containing the current Atari frame
 * scanlines: non-zero → darken every other output row to simulate CRT scanlines
 */
fragment float4 emulatorFragment(VertexOut         in        [[stage_in]],
                                 texture2d<float>  tex       [[texture(0)]],
                                 constant int     &scanlines [[buffer(0)]]) {
    constexpr sampler s(filter::nearest, address::clamp_to_edge);
    float4 color = tex.sample(s, in.uv);

    if (scanlines && fmod(floor(in.position.y), 2.0f) < 1.0f)
        color.rgb *= 0.70f;

    return color;
}
