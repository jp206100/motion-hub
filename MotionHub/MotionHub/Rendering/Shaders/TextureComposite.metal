//
//  TextureComposite.metal
//  Motion Hub
//
//  Blends inspiration pack textures with procedural visuals
//  Creates unique looks based on uploaded media - photos, videos, logos
//  The artist's brand assets directly shape the visual output
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
static float2 kenBurns(float2 uv, float time, float seed) {
    float panX = sin(time * 0.15 + seed * 3.14) * 0.15;
    float panY = cos(time * 0.12 + seed * 2.17) * 0.1;
    float zoom = 0.7 + sin(time * 0.08 + seed * 1.37) * 0.1;
    float2 center = float2(0.5 + panX, 0.5 + panY);
    return center + (uv - 0.5) * zoom;
}

fragment float4 textureCompositeFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    constant ColorPalette* palettes [[buffer(1)]],
    texture2d<float> baseTexture [[texture(0)]],
    texture2d<float> inspirationTex0 [[texture(1)]],
    texture2d<float> inspirationTex1 [[texture(2)]],
    texture2d<float> inspirationTex2 [[texture(3)]],
    texture2d<float> inspirationTex3 [[texture(4)]]
) {
    constexpr sampler clampSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear, address::repeat);

    float2 uv = in.texCoord;
    float t = u.time * u.speed * 0.2;
    float pulse = u.pulseStrength;

    // ==========================================
    // DIAGNOSTIC: bright magenta bar at top 3% of screen
    // If you see this bar, the shader pipeline works
    // ==========================================
    if (uv.y < 0.03) {
        return float4(1.0, 0.0, 1.0, 1.0); // bright magenta
    }

    // Sample base procedural layer (output of Pass 1)
    float4 baseColor = baseTexture.sample(clampSampler, uv);
    float3 result = baseColor.rgb;

    // If no inspiration textures, just return base with audio effects
    if (u.textureCount == 0) {
        float bassPulse = 1.0 + u.audioBass * pulse * 0.8;
        result *= bassPulse;
        return float4(result, 1.0);
    }

    // ==========================================
    // SIMPLE TEXTURE BLENDING
    // Just mix inspiration textures into the base using safe operations
    // ==========================================

    // Texture 0: Primary brand layer with Ken Burns motion
    if (u.textureCount >= 1) {
        float2 texUV = kenBurns(uv, t, 0.0);
        float4 tex = inspirationTex0.sample(clampSampler, texUV);
        // Simple mix - 30% texture, 70% base. Can never produce darker than min(base, tex)
        result = mix(result, tex.rgb, 0.3);
    }

    // Texture 1: Subtle secondary layer
    if (u.textureCount >= 2) {
        float2 texUV = uv + float2(sin(t * 0.3) * 0.05, cos(t * 0.2) * 0.05);
        float4 tex = inspirationTex1.sample(clampSampler, texUV);
        // Screen blend at low opacity - can only brighten
        float3 screened = tcBlendScreen(result, tex.rgb);
        result = mix(result, screened, 0.15);
    }

    // Texture 2: Subtle third layer
    if (u.textureCount >= 3) {
        float2 texUV = uv + float2(t * 0.02, -t * 0.01);
        float4 tex = inspirationTex2.sample(texSampler, texUV);
        result = mix(result, tex.rgb, 0.1);
    }

    // ==========================================
    // AUDIO REACTIVITY (same as workingComposite)
    // ==========================================

    // Bass pulse brightness
    float bassPulseAmt = 1.0 + u.audioBass * pulse * 0.8;
    result *= bassPulseAmt;

    // Mid-frequency saturation boost
    float3 hsv = rgb2hsv(result);
    hsv.y = clamp(hsv.y + u.audioMid * u.intensity * 0.3, 0.0, 1.0);
    result = hsv2rgb(hsv);

    // High-frequency sparkle
    float highGlow = u.audioHigh * pulse * 0.2;
    result += result * highGlow;

    // Peak flash for transients
    float peakFlash = u.audioPeak * pulse * 0.3;
    result += float3(peakFlash);

    // Clamp output
    result = clamp(result, 0.0, 1.0);

    return float4(result, 1.0);
}
