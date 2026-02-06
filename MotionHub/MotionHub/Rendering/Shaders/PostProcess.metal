//
//  PostProcess.metal
//  Motion Hub
//
//  Post-processing shader (grain, color grading, vignette)
//  Uses inspiration pack palette for artist-specific color grading
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations
float hash(float2 p);
float3 rgb2hsv(float3 c);
float3 hsv2rgb(float3 c);
float3 blendScreen(float3 base, float3 blend);

fragment float4 postProcessFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    constant ColorPalette* palettes [[buffer(1)]],
    texture2d<float> inputTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float2 uv = in.texCoord;

    // Sample input texture
    float4 color;
    if (inputTexture.get_width() > 0) {
        color = inputTexture.sample(textureSampler, uv);
    } else {
        // Generate a simple animated pattern as fallback
        float2 p = uv * 2.0 - 1.0;
        float t = u.time * u.speed * 0.1;
        float pattern = sin(p.x * 5.0 + t) * cos(p.y * 5.0 - t);
        pattern += u.audioFreqBand * u.intensity;

        float hue = fract(pattern * 0.2 + t * 0.1);
        float3 rgb = hsv2rgb(float3(hue, 0.6, 0.5));
        color = float4(rgb, 1.0);
    }

    // Film grain
    float grain = (hash(uv + fract(u.time)) - 0.5) * 0.08;
    color.rgb += grain;

    // Subtle vignette
    float2 vignetteUV = uv * 2.0 - 1.0;
    float vignette = 1.0 - length(vignetteUV) * 0.5;
    vignette = smoothstep(0.3, 1.0, vignette);
    color.rgb *= vignette;

    // Color grading (muted, industrial look)
    color.rgb = pow(color.rgb, float3(1.1));  // Slight contrast boost

    // Palette-based color grading: tint highlights and shadows
    // toward the artist's brand colors
    if (palettes != nullptr && palettes[0].colorCount >= 2) {
        ColorPalette pal = palettes[0];
        float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));

        // Shadows tinted toward darkest palette color
        float3 shadowTint = pal.colors[0].rgb;
        float shadowMask = 1.0 - smoothstep(0.0, 0.4, luma);
        color.rgb = mix(color.rgb, color.rgb * shadowTint * 2.0, shadowMask * u.intensity * 0.15);

        // Highlights tinted toward brightest palette color
        float3 highlightTint = pal.colors[min(pal.colorCount - 1, 5)].rgb;
        float highlightMask = smoothstep(0.6, 1.0, luma);
        color.rgb = mix(color.rgb, blendScreen(color.rgb, highlightTint), highlightMask * u.intensity * 0.12);
    } else {
        // Default subtle desaturation for industrial aesthetic
        float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
        color.rgb = mix(color.rgb, float3(luma), 0.15);
    }

    // Apply color shift
    if (u.colorShift > 0.01) {
        float3 hsv = rgb2hsv(color.rgb);
        hsv.x = fract(hsv.x + u.colorShift);
        color.rgb = hsv2rgb(hsv);
    }

    // Monochrome mode
    if (u.isMonochrome) {
        float monoLuma = dot(color.rgb, float3(0.299, 0.587, 0.114));
        color.rgb = float3(monoLuma);
    }

    return color;
}

