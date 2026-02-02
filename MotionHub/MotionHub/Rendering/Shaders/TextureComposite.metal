//
//  TextureComposite.metal
//  Motion Hub
//
//  Blends inspiration pack textures with procedural visuals
//  Creates unique looks based on uploaded media
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations
float hash(float2 p);
float3 hash3(float2 p);
float noise(float2 p);
float fbm(float2 p, int octaves);
float3 rgb2hsv(float3 c);
float3 hsv2rgb(float3 c);

// MARK: - Blend Modes

float3 blendMultiply(float3 base, float3 blend) {
    return base * blend;
}

float3 blendScreen(float3 base, float3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

float3 blendOverlay(float3 base, float3 blend) {
    float3 result;
    result.r = base.r < 0.5 ? 2.0 * base.r * blend.r : 1.0 - 2.0 * (1.0 - base.r) * (1.0 - blend.r);
    result.g = base.g < 0.5 ? 2.0 * base.g * blend.g : 1.0 - 2.0 * (1.0 - base.g) * (1.0 - blend.g);
    result.b = base.b < 0.5 ? 2.0 * base.b * blend.b : 1.0 - 2.0 * (1.0 - base.b) * (1.0 - blend.b);
    return result;
}

float3 blendSoftLight(float3 base, float3 blend) {
    float3 result;
    for (int i = 0; i < 3; i++) {
        if (blend[i] < 0.5) {
            result[i] = base[i] - (1.0 - 2.0 * blend[i]) * base[i] * (1.0 - base[i]);
        } else {
            float d = base[i] < 0.25 ? ((16.0 * base[i] - 12.0) * base[i] + 4.0) * base[i] : sqrt(base[i]);
            result[i] = base[i] + (2.0 * blend[i] - 1.0) * (d - base[i]);
        }
    }
    return result;
}

float3 blendColorDodge(float3 base, float3 blend) {
    return base / max(1.0 - blend, 0.001);
}

float3 blendDifference(float3 base, float3 blend) {
    return abs(base - blend);
}

// MARK: - UV Distortion Effects

// Ripple/wave distortion tied to audio
float2 audioRipple(float2 uv, float time, float audioLevel, float intensity) {
    float2 center = float2(0.5, 0.5);
    float2 toCenter = uv - center;
    float dist = length(toCenter);

    // Ripple emanating from center
    float ripple = sin(dist * 20.0 - time * 5.0) * audioLevel * intensity * 0.02;

    return uv + normalize(toCenter + 0.001) * ripple;
}

// Zoom pulse tied to bass
float2 bassPulse(float2 uv, float bassLevel, float intensity) {
    float2 center = float2(0.5, 0.5);
    float2 toCenter = uv - center;

    // Zoom in/out based on bass
    float zoom = 1.0 - bassLevel * intensity * 0.1;

    return center + toCenter * zoom;
}

// Swirl distortion
float2 swirlDistort(float2 uv, float time, float audioLevel, float intensity) {
    float2 center = float2(0.5, 0.5);
    float2 toCenter = uv - center;
    float dist = length(toCenter);
    float angle = atan2(toCenter.y, toCenter.x);

    // Swirl amount based on distance and audio
    float swirlAmount = (1.0 - dist) * audioLevel * intensity * 0.5;
    angle += swirlAmount * sin(time * 2.0);

    return center + float2(cos(angle), sin(angle)) * dist;
}

// MARK: - Simplified Texture Composite Shader (minimal parameters)
// This version only takes the base texture - no inspiration textures or palette

fragment float4 textureCompositeSimpleFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> baseTexture [[texture(0)]]
) {
    constexpr sampler clampSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    float2 uv = in.texCoord;
    float t = u.time * u.speed * 0.2;
    float audioMod = u.audioFreqBand;
    float bassLevel = u.audioBass;
    float intensity = u.intensity;

    // Apply audio-reactive UV distortion
    float2 distortedUV = audioRipple(uv, t, audioMod, intensity);
    distortedUV = bassPulse(distortedUV, bassLevel, intensity);

    // Sample base texture with distorted UVs
    float4 baseColor = baseTexture.sample(clampSampler, distortedUV);

    // Audio-reactive brightness pulse
    float bassPulseAmount = 1.0 + bassLevel * intensity * 0.3;
    baseColor.rgb *= bassPulseAmount;

    return baseColor;
}

// MARK: - Full Texture Composite Shader (for when inspiration textures are loaded)

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
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear, address::repeat);
    constexpr sampler clampSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    float2 uv = in.texCoord;
    float t = u.time * u.speed * 0.2;
    float audioMod = u.audioFreqBand;
    float bassLevel = u.audioBass;
    float intensity = u.intensity;

    // Sample base procedural layer
    float4 baseColor = baseTexture.sample(clampSampler, uv);

    // If no inspiration textures, just return base with some audio effects
    if (u.textureCount == 0) {
        // Apply audio-reactive UV distortion to base
        float2 distortedUV = audioRipple(uv, t, audioMod, intensity);
        distortedUV = bassPulse(distortedUV, bassLevel, intensity);
        return baseTexture.sample(clampSampler, distortedUV);
    }

    // === TEXTURE SAMPLING WITH MOTION ===

    // Create animated UV coordinates for texture sampling
    float2 texUV0 = uv;
    float2 texUV1 = uv;
    float2 texUV2 = uv;
    float2 texUV3 = uv;

    // Each texture gets different motion based on audio
    // Texture 0: Slow drift with bass response
    texUV0 += float2(t * 0.05, t * 0.03);
    texUV0 = bassPulse(texUV0, bassLevel, intensity * 0.5);

    // Texture 1: Swirl motion
    texUV1 = swirlDistort(uv, t, audioMod, intensity * 0.3);
    texUV1 += float2(sin(t * 0.3) * 0.1, cos(t * 0.2) * 0.1);

    // Texture 2: Ripple effect
    texUV2 = audioRipple(uv, t * 1.5, audioMod, intensity);

    // Texture 3: Kaleidoscope-like motion
    float2 centered = uv * 2.0 - 1.0;
    float angle = atan2(centered.y, centered.x) + t * 0.2;
    float radius = length(centered) * (1.0 + audioMod * intensity * 0.2);
    texUV3 = float2(cos(angle), sin(angle)) * radius * 0.5 + 0.5;

    // Sample inspiration textures
    float4 tex0 = inspirationTex0.sample(texSampler, texUV0);
    float4 tex1 = inspirationTex1.sample(texSampler, texUV1);
    float4 tex2 = inspirationTex2.sample(texSampler, texUV2);
    float4 tex3 = inspirationTex3.sample(texSampler, texUV3);

    // === BLEND TEXTURES WITH BASE ===

    float3 result = baseColor.rgb;

    // Blend mode selection based on time and audio
    int blendMode = int(floor(t * 0.2 + audioMod * 3.0)) % 6;

    // Layer textures with different blend modes and opacity
    if (u.textureCount >= 1 && tex0.a > 0.01) {
        float opacity = 0.3 + audioMod * intensity * 0.4;
        float3 blended;
        switch (blendMode) {
            case 0: blended = blendOverlay(result, tex0.rgb); break;
            case 1: blended = blendScreen(result, tex0.rgb); break;
            case 2: blended = blendSoftLight(result, tex0.rgb); break;
            case 3: blended = blendMultiply(result, tex0.rgb); break;
            case 4: blended = blendColorDodge(result, tex0.rgb); break;
            default: blended = blendDifference(result, tex0.rgb); break;
        }
        result = mix(result, blended, opacity * tex0.a);
    }

    if (u.textureCount >= 2 && tex1.a > 0.01) {
        float opacity = 0.2 + bassLevel * intensity * 0.3;
        float3 blended = blendSoftLight(result, tex1.rgb);
        result = mix(result, blended, opacity * tex1.a);
    }

    if (u.textureCount >= 3 && tex2.a > 0.01) {
        float opacity = 0.15 + u.audioMid * intensity * 0.25;
        float3 blended = blendOverlay(result, tex2.rgb);
        result = mix(result, blended, opacity * tex2.a);
    }

    if (u.textureCount >= 4 && tex3.a > 0.01) {
        float opacity = 0.1 + u.audioHigh * intensity * 0.2;
        float3 blended = blendScreen(result, tex3.rgb);
        result = mix(result, blended, opacity * tex3.a);
    }

    // === APPLY COLOR PALETTE FROM INSPIRATION ===

    // Use extracted colors to tint the result
    if (palettes != nullptr) {
        ColorPalette palette = palettes[0];
        if (palette.colorCount > 0) {
            // Map brightness to palette colors
            float luma = dot(result, float3(0.299, 0.587, 0.114));
            int colorIndex = int(luma * float(palette.colorCount - 1));
            colorIndex = clamp(colorIndex, 0, palette.colorCount - 1);

            float3 paletteColor = palette.colors[colorIndex].rgb;

            // Subtle tinting based on intensity
            result = mix(result, result * paletteColor * 1.5, intensity * 0.3);
        }
    }

    // === AUDIO-REACTIVE PULSATION ===

    // Global brightness pulse on bass hits
    float bassPulseAmount = 1.0 + bassLevel * intensity * 0.5;
    result *= bassPulseAmount;

    // Saturation boost on high frequencies
    float3 hsv = rgb2hsv(result);
    hsv.y = clamp(hsv.y + u.audioHigh * intensity * 0.3, 0.0, 1.0);
    result = hsv2rgb(hsv);

    // Clamp output
    result = clamp(result, 0.0, 1.0);

    return float4(result, 1.0);
}
