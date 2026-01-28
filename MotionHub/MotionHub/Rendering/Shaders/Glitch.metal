//
//  Glitch.metal
//  Motion Hub
//
//  Enhanced glitch effects shader with stutter, frame freeze, and video-style effects
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations
float hash(float2 p);
float hash(float n);
float3 hash3(float2 p);

// MARK: - Glitch Helper Functions

// Stepped time for stutter/freeze effect
float stutterTime(float time, float glitch, float audioLevel) {
    // Create random freeze points based on glitch amount
    float freezeChance = glitch * 0.5;
    float freezeBlock = floor(time * (2.0 + glitch * 8.0));
    float shouldFreeze = step(1.0 - freezeChance, hash(freezeBlock));

    // When audio peaks, trigger freeze
    float audioPeak = step(0.7, audioLevel);

    if (shouldFreeze > 0.5 || (audioPeak > 0.5 && glitch > 0.3)) {
        // Return the time at the start of this block (frozen)
        return freezeBlock / (2.0 + glitch * 8.0);
    }
    return time;
}

// Block corruption - VHS-style tracking errors
float2 blockCorruption(float2 uv, float time, float glitch) {
    // Horizontal bands that shift
    float bandHeight = 0.05 + hash(floor(time * 3.0)) * 0.1;
    float band = floor(uv.y / bandHeight);
    float bandNoise = hash(float2(band, floor(time * 5.0)));

    float2 offset = float2(0.0);

    // Severe horizontal displacement on random bands
    if (bandNoise > 1.0 - glitch * 0.4) {
        offset.x = (bandNoise - 0.5) * glitch * 0.3;

        // Sometimes completely corrupt the band
        if (bandNoise > 1.0 - glitch * 0.1) {
            offset.y = hash(band + time) * 0.1 * glitch;
        }
    }

    return offset;
}

// Color channel swap/corruption
float3 colorCorruption(float3 color, float2 uv, float time, float glitch) {
    float swapChance = hash(floor(time * 4.0) + floor(uv.y * 20.0));

    if (swapChance > 1.0 - glitch * 0.3) {
        // Swap color channels randomly
        int swapType = int(hash(floor(time * 5.0)) * 6.0);
        switch (swapType) {
            case 0: color = color.rbg; break;
            case 1: color = color.grb; break;
            case 2: color = color.gbr; break;
            case 3: color = color.brg; break;
            case 4: color = color.bgr; break;
            default: break;
        }
    }

    return color;
}

// VHS tracking lines
float vhsTracking(float2 uv, float time, float glitch) {
    float tracking = 0.0;

    // Rolling horizontal lines
    float rollSpeed = 5.0 + glitch * 10.0;
    float rollY = fract(uv.y + time * 0.1);
    float rollLine = smoothstep(0.0, 0.02, abs(rollY - fract(time * rollSpeed * 0.01)));
    tracking += (1.0 - rollLine) * glitch * 0.5;

    // Static noise bands
    float staticBand = hash(floor(uv.y * 50.0 + time * 20.0));
    if (staticBand > 1.0 - glitch * 0.2) {
        tracking += 0.3;
    }

    return tracking;
}

// Digital block artifacts
float3 digitalBlocks(float2 uv, float time, float glitch, float3 originalColor) {
    float blockSize = 0.02 + glitch * 0.08;
    float2 blockUV = floor(uv / blockSize) * blockSize;
    float blockNoise = hash(blockUV + floor(time * 8.0));

    if (blockNoise > 1.0 - glitch * 0.15) {
        // Replace with solid color block
        float3 blockColor = hash3(blockUV + time);
        return mix(originalColor, blockColor, glitch * 0.8);
    }

    return originalColor;
}

// Interlacing effect
float interlace(float2 uv, float time, float glitch) {
    float scanline = floor(uv.y * 480.0); // 480 scanlines like old video
    float isOddFrame = floor(fract(time * 30.0) * 2.0); // 30fps interlacing
    float isOddLine = fmod(scanline, 2.0);

    // Slight mismatch between fields
    float fieldShift = (isOddFrame == isOddLine) ? 0.0 : glitch * 0.003;
    return fieldShift;
}

// MARK: - Main Glitch Fragment Shader

fragment float4 glitchFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> inputTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    float2 uv = in.texCoord;
    float glitch = u.glitchAmount;
    float audioLevel = u.audioFreqBand;

    // Skip processing if no glitch
    if (glitch < 0.01) {
        return inputTexture.sample(textureSampler, uv);
    }

    // === STUTTER/FREEZE EFFECT ===
    // Time-based stuttering that responds to audio
    float effectiveTime = stutterTime(u.time, glitch, audioLevel);

    // === BLOCK CORRUPTION (VHS tracking) ===
    float2 corruptionOffset = blockCorruption(uv, effectiveTime, glitch);

    // === INTERLACING ===
    float interlaceOffset = interlace(uv, effectiveTime, glitch);

    // Apply UV distortions
    float2 distortedUV = uv + corruptionOffset;
    distortedUV.x += interlaceOffset;

    // === CHROMATIC ABERRATION (enhanced) ===
    // Stronger RGB split that varies across screen
    float distFromCenter = length(uv - 0.5);
    float rgbSplit = glitch * 0.02 * (1.0 + audioLevel * 2.0) * (1.0 + distFromCenter);

    // Angle-based split for more interesting effect
    float splitAngle = effectiveTime * 0.5;
    float2 redOffset = float2(cos(splitAngle), sin(splitAngle)) * rgbSplit;
    float2 blueOffset = float2(cos(splitAngle + 2.094), sin(splitAngle + 2.094)) * rgbSplit;

    float4 r = inputTexture.sample(textureSampler, distortedUV + redOffset);
    float4 g = inputTexture.sample(textureSampler, distortedUV);
    float4 b = inputTexture.sample(textureSampler, distortedUV + blueOffset);

    float3 color = float3(r.r, g.g, b.b);

    // === DIGITAL BLOCK ARTIFACTS ===
    color = digitalBlocks(uv, effectiveTime, glitch, color);

    // === COLOR CORRUPTION ===
    color = colorCorruption(color, uv, effectiveTime, glitch);

    // === VHS TRACKING LINES ===
    float tracking = vhsTracking(uv, effectiveTime, glitch);
    color = mix(color, float3(1.0), tracking);

    // === SCAN LINES ===
    float scanLineIntensity = glitch * 0.3;
    float scanLine = sin(uv.y * 800.0) * 0.5 + 0.5;
    color *= 1.0 - scanLine * scanLineIntensity;

    // === STATIC NOISE ===
    float staticNoise = hash(uv * 1000.0 + effectiveTime * 100.0);
    float staticIntensity = glitch * 0.15 * (1.0 + audioLevel);
    color = mix(color, float3(staticNoise), staticIntensity);

    // === HORIZONTAL TEARING ===
    float tearChance = hash(floor(effectiveTime * 6.0));
    if (tearChance > 1.0 - glitch * 0.2) {
        float tearY = hash(floor(effectiveTime * 7.0));
        float tearHeight = 0.05 + hash(effectiveTime) * 0.1;
        if (abs(uv.y - tearY) < tearHeight) {
            float tearOffset = (hash(uv.y + effectiveTime) - 0.5) * glitch * 0.2;
            float4 tornSample = inputTexture.sample(textureSampler, float2(uv.x + tearOffset, uv.y));
            color = tornSample.rgb;
        }
    }

    // === BRIGHTNESS FLICKER ===
    float flicker = 1.0 + (hash(floor(effectiveTime * 15.0)) - 0.5) * glitch * 0.3;
    color *= flicker;

    // Clamp final output
    color = clamp(color, 0.0, 1.0);

    return float4(color, 1.0);
}
