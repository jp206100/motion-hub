//
//  BaseLayer.metal
//  Motion Hub
//
//  Base layer shader - animated gradient using color palette
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations from Common.metal
float hash(float2 p);
float noise(float2 p);
float3 rgb2hsv(float3 c);
float3 hsv2rgb(float3 c);

fragment float4 baseLayerFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    float2 uv = in.texCoord;

    // Animated gradient
    float t = u.time * u.speed * 0.1;
    float audioMod = u.audioFreqBand * u.intensity;

    // Create procedural gradient with audio reactivity
    float2 p = uv * 2.0 - 1.0;
    float angle = atan2(p.y, p.x);
    float radius = length(p);

    // Multi-layered noise for interesting patterns
    float n1 = noise(uv * 3.0 + t);
    float n2 = noise(uv * 7.0 - t * 0.5);
    float n3 = noise(float2(angle * 5.0, radius * 8.0) + t);

    float pattern = (n1 + n2 * 0.5 + n3 * 0.3) / 1.8;
    pattern += audioMod * 0.5;

    // Color based on pattern
    float hue = fract(pattern * 0.3 + t * 0.05);
    float sat = 0.6 + audioMod * 0.4;
    float val = 0.4 + pattern * 0.3 + audioMod * 0.3;

    float3 color = hsv2rgb(float3(hue, sat, val));

    // Apply accent color tint (cyan-ish from spec)
    float3 accentColor = float3(0.24, 0.85, 0.85); // #3dd9d9
    color = mix(color, color * accentColor, 0.3);

    // Monochrome mode
    if (u.isMonochrome) {
        float luma = dot(color, float3(0.299, 0.587, 0.114));
        color = float3(luma);
    }

    return float4(color, 1.0);
}
