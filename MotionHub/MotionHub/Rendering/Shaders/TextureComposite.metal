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

float3 blendHardLight(float3 base, float3 blend) {
    float3 result;
    result.r = blend.r < 0.5 ? 2.0 * base.r * blend.r : 1.0 - 2.0 * (1.0 - base.r) * (1.0 - blend.r);
    result.g = blend.g < 0.5 ? 2.0 * base.g * blend.g : 1.0 - 2.0 * (1.0 - base.g) * (1.0 - blend.g);
    result.b = blend.b < 0.5 ? 2.0 * base.b * blend.b : 1.0 - 2.0 * (1.0 - base.b) * (1.0 - blend.b);
    return result;
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

// Ken Burns style slow pan/zoom for photo reveals
float2 kenBurns(float2 uv, float time, float seed) {
    float panX = sin(time * 0.15 + seed * 3.14) * 0.15;
    float panY = cos(time * 0.12 + seed * 2.17) * 0.1;
    float zoom = 0.7 + sin(time * 0.08 + seed * 1.37) * 0.1;

    float2 center = float2(0.5 + panX, 0.5 + panY);
    return center + (uv - 0.5) * zoom;
}

// MARK: - Full Texture Composite Shader
// Heavily integrates inspiration pack assets into the visual output

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
    float midLevel = u.audioMid;
    float highLevel = u.audioHigh;
    float intensity = u.intensity;
    float pulse = u.pulseStrength;
    float peak = u.audioPeak;

    // Sample base procedural layer
    float4 baseColor = baseTexture.sample(clampSampler, uv);

    // If no inspiration textures, apply audio effects and return
    if (u.textureCount == 0) {
        float2 distortedUV = audioRipple(uv, t, audioMod, intensity);
        distortedUV = bassPulse(distortedUV, bassLevel, intensity);
        float4 result = baseTexture.sample(clampSampler, distortedUV);
        float bassPulseAmt = 1.0 + bassLevel * pulse * 0.8;
        result.rgb *= bassPulseAmt;
        return result;
    }

    // ========================================================
    // INSPIRATION TEXTURE INTEGRATION
    // Each texture gets unique motion, timing, and blend behavior
    // ========================================================

    // --- TEXTURE 0: PRIMARY BRAND LAYER ---
    // Slow Ken Burns pan/zoom with audio-reactive scaling
    // This is the most visible inspiration layer
    float2 texUV0 = kenBurns(uv, t, 0.0);
    texUV0 = bassPulse(texUV0, bassLevel, intensity * 0.3);
    float4 tex0 = inspirationTex0.sample(clampSampler, texUV0);

    // --- TEXTURE 1: RHYTHM LAYER ---
    // Swirl motion synced to mid frequencies
    float2 texUV1 = swirlDistort(uv, t, midLevel, intensity * 0.4);
    texUV1 += float2(sin(t * 0.3) * 0.1, cos(t * 0.2) * 0.1);
    float4 tex1 = inspirationTex1.sample(texSampler, texUV1);

    // --- TEXTURE 2: ENERGY LAYER ---
    // Fast ripple tied to high frequencies
    float2 texUV2 = audioRipple(uv, t * 2.0, highLevel, intensity);
    texUV2 += float2(t * 0.08, -t * 0.05);
    float4 tex2 = inspirationTex2.sample(texSampler, texUV2);

    // --- TEXTURE 3: ATMOSPHERIC LAYER ---
    // Kaleidoscope-like radial motion
    float2 centered = uv * 2.0 - 1.0;
    float angle = atan2(centered.y, centered.x) + t * 0.15;
    float radius = length(centered) * (1.0 + audioMod * intensity * 0.2);
    float2 texUV3 = float2(cos(angle), sin(angle)) * radius * 0.5 + 0.5;
    float4 tex3 = inspirationTex3.sample(texSampler, texUV3);

    // ========================================================
    // BLEND MODES - cycle through based on time, creating variety
    // ========================================================

    float3 result = baseColor.rgb;

    // Determine overall blend phase (changes every ~8 seconds)
    int blendPhase = int(floor(t * 0.125)) % 4;

    // --- Layer 0: Primary brand texture (STRONG presence) ---
    if (u.textureCount >= 1 && tex0.a > 0.01) {
        // Higher base opacity - the artist's content should be clearly visible
        float opacity = 0.45 + audioMod * intensity * 0.35;

        // Beat-synced opacity boost - flash the image on strong beats
        float beatBoost = peak * pulse * 0.3;
        opacity = min(opacity + beatBoost, 0.95);

        float3 blended;
        switch (blendPhase) {
            case 0: blended = blendOverlay(result, tex0.rgb); break;
            case 1: blended = blendScreen(result, tex0.rgb); break;
            case 2: blended = blendHardLight(result, tex0.rgb); break;
            default: blended = blendSoftLight(result, tex0.rgb); break;
        }
        result = mix(result, blended, opacity);
    }

    // --- Layer 1: Rhythm texture (moderate presence, bass-reactive) ---
    if (u.textureCount >= 2 && tex1.a > 0.01) {
        float opacity = 0.3 + bassLevel * pulse * 0.4;
        float3 blended = blendOverlay(result, tex1.rgb);
        result = mix(result, blended, opacity);
    }

    // --- Layer 2: Energy texture (high-freq reactive) ---
    if (u.textureCount >= 3 && tex2.a > 0.01) {
        float opacity = 0.2 + highLevel * intensity * 0.35;
        float3 blended = blendScreen(result, tex2.rgb);
        result = mix(result, blended, opacity);
    }

    // --- Layer 3: Atmospheric depth ---
    if (u.textureCount >= 4 && tex3.a > 0.01) {
        float opacity = 0.15 + midLevel * intensity * 0.25;
        float3 blended = blendSoftLight(result, tex3.rgb);
        result = mix(result, blended, opacity);
    }

    // ========================================================
    // PHOTO FLASH / REVEAL SYSTEM
    // On strong beats, briefly reveal a full-opacity inspiration image
    // This creates those iconic VJ moments where the brand imagery
    // punches through the visuals
    // ========================================================

    float flashTrigger = step(0.75, peak * pulse);
    if (flashTrigger > 0.5 && u.textureCount >= 1) {
        // Pick which texture to flash based on time
        int flashTex = int(floor(t * 2.0)) % u.textureCount;

        float2 flashUV = uv;
        // Slight zoom on flash for impact
        float2 flashCenter = float2(0.5, 0.5);
        flashUV = flashCenter + (flashUV - flashCenter) * 0.85;

        float4 flashColor;
        switch (flashTex) {
            case 0: flashColor = inspirationTex0.sample(clampSampler, flashUV); break;
            case 1: flashColor = inspirationTex1.sample(clampSampler, flashUV); break;
            case 2: flashColor = inspirationTex2.sample(clampSampler, flashUV); break;
            default: flashColor = inspirationTex3.sample(clampSampler, flashUV); break;
        }

        // Flash intensity based on peak strength
        // Quick attack, slightly slower decay creates a strobe-like feel
        float flashIntensity = peak * pulse * 0.6;
        result = mix(result, flashColor.rgb, flashIntensity);
    }

    // ========================================================
    // TEXTURE-DRIVEN DISPLACEMENT
    // Use the brightness of inspiration textures to distort the
    // base layer - creates organic warping shaped by the artist's imagery
    // ========================================================

    if (u.textureCount >= 1) {
        float texBrightness = dot(tex0.rgb, float3(0.299, 0.587, 0.114));
        float2 displace = (texBrightness - 0.5) * intensity * 0.03;
        float2 displacedUV = uv + displace * (1.0 + audioMod);
        float4 displaced = baseTexture.sample(clampSampler, displacedUV);
        // Subtle blend of displaced version
        result = mix(result, displaced.rgb, 0.15 + audioMod * 0.1);
    }

    // ========================================================
    // SILHOUETTE / EDGE OVERLAY
    // Uses high-contrast version of textures as overlays
    // Creates logo watermark and brand silhouette effects
    // ========================================================

    if (u.textureCount >= 1) {
        // Extract edges from primary texture using luminance gradient
        float2 texelSize = float2(1.0 / 512.0); // approximate
        float lumCenter = dot(tex0.rgb, float3(0.299, 0.587, 0.114));
        float lumRight = dot(inspirationTex0.sample(clampSampler, texUV0 + float2(texelSize.x, 0.0)).rgb,
                            float3(0.299, 0.587, 0.114));
        float lumDown = dot(inspirationTex0.sample(clampSampler, texUV0 + float2(0.0, texelSize.y)).rgb,
                           float3(0.299, 0.587, 0.114));
        float edge = length(float2(lumCenter - lumRight, lumCenter - lumDown)) * 8.0;
        edge = smoothstep(0.1, 0.6, edge);

        // Show edges as bright outlines synced to audio
        float edgeOpacity = edge * intensity * (0.3 + audioMod * 0.4);
        float3 edgeColor;
        if (palettes != nullptr && palettes[0].colorCount > 0) {
            edgeColor = palettes[0].colors[0].rgb;
        } else {
            edgeColor = float3(1.0);
        }
        result += edgeColor * edgeOpacity;
    }

    // ========================================================
    // COLOR PALETTE GRADING
    // Map the output through the artist's extracted color palette
    // This ensures the overall color feel matches their brand
    // ========================================================

    if (palettes != nullptr) {
        ColorPalette palette = palettes[0];
        if (palette.colorCount > 0) {
            // Map brightness to palette colors for tinting
            float luma = dot(result, float3(0.299, 0.587, 0.114));
            int colorIndex = int(luma * float(palette.colorCount - 1));
            colorIndex = clamp(colorIndex, 0, palette.colorCount - 1);

            float3 paletteColor = palette.colors[colorIndex].rgb;

            // Stronger palette influence - this shapes the color identity
            result = mix(result, result * paletteColor * 1.5, intensity * 0.4);

            // Also tint darker areas toward the darkest palette color
            float3 darkColor = palette.colors[0].rgb;
            float shadow = 1.0 - smoothstep(0.0, 0.3, luma);
            result = mix(result, darkColor * result * 2.0, shadow * intensity * 0.25);
        }
    }

    // ========================================================
    // AUDIO-REACTIVE PULSATION
    // ========================================================

    // Bass pulse brightness
    float bassPulseAmount = 1.0 + bassLevel * pulse * 0.6;
    result *= bassPulseAmount;

    // Mid-frequency saturation boost
    float3 hsv = rgb2hsv(result);
    hsv.y = clamp(hsv.y + midLevel * intensity * 0.3, 0.0, 1.0);
    result = hsv2rgb(hsv);

    // High-frequency sparkle
    float highGlow = highLevel * pulse * 0.15;
    result += result * highGlow;

    // Clamp output
    result = clamp(result, 0.0, 1.0);

    return float4(result, 1.0);
}
