//
//  Glitch.metal
//  Motion Hub
//
//  Glitch effects shader
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations
float hash(float2 p);
float hash(float n);

fragment float4 glitchFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> inputTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float2 uv = in.texCoord;
    float glitch = u.glitchAmount;

    // Skip if no glitch
    if (glitch < 0.01) {
        return inputTexture.sample(textureSampler, uv);
    }

    // Random block displacement
    float blockSize = 0.05 + glitch * 0.1;
    float2 block = floor(uv / blockSize) * blockSize;
    float noiseVal = hash(block + floor(u.time * 10.0));

    float2 offset = float2(0.0);
    if (noiseVal > 1.0 - glitch * 0.3) {
        offset.x = (hash(block * 2.0) - 0.5) * glitch * 0.1;
    }

    // Scan line distortion
    float scanLine = hash(floor(uv.y * 200.0 + u.time * 50.0));
    if (scanLine > 1.0 - glitch * 0.2) {
        offset.x += (scanLine - 0.5) * glitch * 0.05;
    }

    // RGB split (chromatic aberration)
    float rgbSplit = glitch * 0.01 * (1.0 + u.audioFreqBand);
    float4 r = inputTexture.sample(textureSampler, uv + offset + float2(rgbSplit, 0));
    float4 g = inputTexture.sample(textureSampler, uv + offset);
    float4 b = inputTexture.sample(textureSampler, uv + offset - float2(rgbSplit, 0));

    float4 color = float4(r.r, g.g, b.b, 1.0);

    // Digital artifacts
    if (hash(floor(uv.y * 100.0) + u.time * 5.0) > 1.0 - glitch * 0.1) {
        color = mix(color, float4(hash(uv + u.time)), 0.5);
    }

    return color;
}
