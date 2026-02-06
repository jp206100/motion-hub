//
//  TextureComposite.metal
//  Motion Hub
//
//  Blends ONE inspiration pack texture with procedural base visuals
//  Uses only 2 texture parameters (matching the proven working pattern)
//  Swift-side cycles through inspiration textures over time for variety
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations
float3 rgb2hsv(float3 c);
float3 hsv2rgb(float3 c);

// Screen blend - always brightens or maintains brightness
static float3 tcBlendScreen(float3 base, float3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

// Ken Burns style slow pan/zoom for photo reveals
static float2 tcKenBurns(float2 uv, float time, float seed) {
    float panX = sin(time * 0.15 + seed * 3.14) * 0.15;
    float panY = cos(time * 0.12 + seed * 2.17) * 0.1;
    float zoom = 0.7 + sin(time * 0.08 + seed * 1.37) * 0.1;
    float2 center = float2(0.5 + panX, 0.5 + panY);
    return center + (uv - 0.5) * zoom;
}

// Inspiration blend: base texture + ONE inspiration texture
// Only 2 texture slots — avoids the multi-texture pipeline issue
fragment float4 inspirationBlendFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> baseTexture [[texture(0)]],
    texture2d<float> inspirationTex [[texture(1)]]
) {
    constexpr sampler clampSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    float2 uv = in.texCoord;
    float t = u.time * u.speed * 0.2;
    float pulse = u.pulseStrength;

    // Sample base procedural layer (output of Pass 1)
    float4 baseColor = baseTexture.sample(clampSampler, uv);
    float3 result = baseColor.rgb;

    // Sample inspiration texture with Ken Burns pan/zoom
    float2 texUV = tcKenBurns(uv, t, 0.0);
    float4 tex = inspirationTex.sample(clampSampler, texUV);

    // Blend: mix 40% inspiration into base
    result = mix(result, tex.rgb, 0.4 * u.intensity);

    // Screen blend for brightness lift from inspiration
    float3 screened = tcBlendScreen(result, tex.rgb);
    result = mix(result, screened, 0.15 * u.intensity);

    // Audio reactivity
    float bassPulseAmt = 1.0 + u.audioBass * pulse * 0.8;
    result *= bassPulseAmt;

    float3 hsv = rgb2hsv(result);
    hsv.y = clamp(hsv.y + u.audioMid * u.intensity * 0.3, 0.0, 1.0);
    result = hsv2rgb(hsv);

    float highGlow = u.audioHigh * pulse * 0.2;
    result += result * highGlow;

    float peakFlash = u.audioPeak * pulse * 0.3;
    result += float3(peakFlash);

    result = clamp(result, 0.0, 1.0);

    return float4(result, 1.0);
}
