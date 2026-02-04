//
//  Glitch.metal
//  Motion Hub
//
//  Authentic video glitch shader with displacement-based effects
//  that warp and distort the actual video content rather than overlaying artifacts
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations
float hash(float2 p);
float hash(float n);
float3 hash3(float2 p);

// MARK: - Displacement-Based Glitch Functions

// Stepped time for stutter/freeze effect
float stutterTime(float time, float glitch, float audioLevel) {
    float freezeChance = glitch * 0.5;
    float freezeBlock = floor(time * (2.0 + glitch * 8.0));
    float shouldFreeze = step(1.0 - freezeChance, hash(freezeBlock));
    float audioPeak = step(0.7, audioLevel);

    if (shouldFreeze > 0.5 || (audioPeak > 0.5 && glitch > 0.3)) {
        return freezeBlock / (2.0 + glitch * 8.0);
    }
    return time;
}

// Wave distortion - creates organic warping of the image
float2 waveDistortion(float2 uv, float time, float glitch, float audioLevel) {
    float2 offset = float2(0.0);

    // Horizontal wave that warps the image
    float waveFreq = 3.0 + glitch * 15.0;
    float waveAmp = glitch * 0.03 * (1.0 + audioLevel);
    offset.x += sin(uv.y * waveFreq + time * 2.0) * waveAmp;

    // Secondary vertical wave for more organic feel
    float vWaveFreq = 5.0 + glitch * 10.0;
    float vWaveAmp = glitch * 0.015 * (1.0 + audioLevel * 0.5);
    offset.y += sin(uv.x * vWaveFreq + time * 1.5) * vWaveAmp;

    // Occasional intense wave burst
    float burstChance = hash(floor(time * 4.0));
    if (burstChance > 1.0 - glitch * 0.3) {
        float burstWave = sin(uv.y * 20.0 + time * 10.0);
        offset.x += burstWave * glitch * 0.08;
    }

    return offset;
}

// Dramatic horizontal line displacement - VHS tracking style
float2 lineDisplacement(float2 uv, float time, float glitch) {
    float2 offset = float2(0.0);

    // Create bands of different heights
    float bandSeed = floor(time * 3.0);
    float bandHeight = 0.02 + hash(bandSeed) * 0.08;
    float band = floor(uv.y / bandHeight);
    float bandHash = hash(float2(band, bandSeed));

    // Strong horizontal shift for affected bands
    if (bandHash > 1.0 - glitch * 0.5) {
        float shiftAmount = (bandHash - 0.5) * 2.0; // -1 to 1
        offset.x = shiftAmount * glitch * 0.4; // Up to 40% of screen width!
    }

    // Thin glitch strips with extreme displacement
    float stripSeed = floor(time * 8.0);
    float stripHeight = 0.005 + hash(stripSeed + 0.5) * 0.015;
    float strip = floor(uv.y / stripHeight);
    float stripHash = hash(float2(strip, stripSeed));

    if (stripHash > 1.0 - glitch * 0.2) {
        // These thin strips can shift dramatically
        offset.x += (stripHash - 0.5) * glitch * 0.6;
    }

    return offset;
}

// Vertical chunk displacement - rolling/jumping effect
float verticalChunkShift(float2 uv, float time, float glitch) {
    float shift = 0.0;

    // Divide screen into vertical chunks that can jump
    float chunkSeed = floor(time * 2.0);
    float numChunks = 3.0 + floor(hash(chunkSeed) * 5.0);
    float chunkIndex = floor(uv.y * numChunks);
    float chunkHash = hash(float2(chunkIndex, chunkSeed));

    // Some chunks jump vertically
    if (chunkHash > 1.0 - glitch * 0.3) {
        float jumpAmount = (chunkHash - 0.5) * glitch * 0.15;
        shift = jumpAmount;
    }

    // Rolling effect - entire image shifts down occasionally
    float rollChance = hash(floor(time * 5.0));
    if (rollChance > 1.0 - glitch * 0.15) {
        float rollAmount = fract(time * 2.0) * glitch * 0.1;
        shift += rollAmount;
    }

    return shift;
}

// Block-based displacement - moves actual content, not solid colors
float2 blockDisplacement(float2 uv, float time, float glitch) {
    float2 offset = float2(0.0);

    // Variable block sizes for more organic look
    float blockSeed = floor(time * 6.0);
    float blockSize = 0.03 + hash(blockSeed) * 0.07;
    float2 blockCoord = floor(uv / blockSize);
    float blockHash = hash(blockCoord + blockSeed);

    // Affected blocks sample from offset positions
    if (blockHash > 1.0 - glitch * 0.25) {
        // Displace to show content from elsewhere in the image
        float2 displaceDir = hash3(blockCoord + time).xy - 0.5;
        offset = displaceDir * glitch * 0.3;
    }

    // Rare extreme block corruption
    if (blockHash > 1.0 - glitch * 0.08) {
        float2 extremeOffset = hash3(blockCoord + time * 2.0).xy - 0.5;
        offset = extremeOffset * glitch * 0.6;
    }

    return offset;
}

// Scan line displacement - individual lines shift
float scanLineShift(float2 uv, float time, float glitch) {
    float lineNum = floor(uv.y * 480.0);
    float lineSeed = floor(time * 10.0);
    float lineHash = hash(float2(lineNum, lineSeed));

    // Occasional line shifts
    if (lineHash > 1.0 - glitch * 0.15) {
        return (lineHash - 0.5) * glitch * 0.1;
    }
    return 0.0;
}

// Interlacing with field displacement
float2 interlaceDisplacement(float2 uv, float time, float glitch) {
    float scanline = floor(uv.y * 480.0);
    float isOddFrame = floor(fract(time * 30.0) * 2.0);
    float isOddLine = fmod(scanline, 2.0);

    float2 offset = float2(0.0);

    // Field shift - odd/even lines from different positions
    if (isOddFrame != isOddLine) {
        offset.x = glitch * 0.005;
        // Occasionally stronger field mismatch
        if (hash(floor(time * 8.0)) > 0.7) {
            offset.x = glitch * 0.02;
        }
    }

    return offset;
}

// Color channel displacement - RGB splits with actual UV offsets
void rgbDisplacement(float2 uv, float time, float glitch, float audioLevel,
                     thread float2& redUV, thread float2& greenUV, thread float2& blueUV) {
    float distFromCenter = length(uv - 0.5);
    float baseSplit = glitch * 0.025 * (1.0 + audioLevel * 2.0) * (1.0 + distFromCenter);

    // Rotating split angle
    float splitAngle = time * 0.5;
    float2 splitDir1 = float2(cos(splitAngle), sin(splitAngle));
    float2 splitDir2 = float2(cos(splitAngle + 2.094), sin(splitAngle + 2.094));
    float2 splitDir3 = float2(cos(splitAngle + 4.189), sin(splitAngle + 4.189));

    // Occasional intense split
    float intenseSplit = 1.0;
    if (hash(floor(time * 6.0)) > 1.0 - glitch * 0.2) {
        intenseSplit = 2.0 + hash(time) * 2.0;
    }

    redUV = uv + splitDir1 * baseSplit * intenseSplit;
    greenUV = uv + splitDir2 * baseSplit * intenseSplit * 0.5;
    blueUV = uv + splitDir3 * baseSplit * intenseSplit;
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
    float effectiveTime = stutterTime(u.time, glitch, audioLevel);

    // === ACCUMULATE ALL DISPLACEMENT EFFECTS ===
    // These all modify UV coordinates to warp the actual image content

    float2 totalDisplacement = float2(0.0);

    // 1. Wave distortion - organic warping
    totalDisplacement += waveDistortion(uv, effectiveTime, glitch, audioLevel);

    // 2. Horizontal line displacement - VHS tracking errors
    totalDisplacement += lineDisplacement(uv, effectiveTime, glitch);

    // 3. Vertical chunk shift - rolling/jumping
    totalDisplacement.y += verticalChunkShift(uv, effectiveTime, glitch);

    // 4. Block displacement - moves content blocks
    totalDisplacement += blockDisplacement(uv, effectiveTime, glitch);

    // 5. Individual scan line shifts
    totalDisplacement.x += scanLineShift(uv, effectiveTime, glitch);

    // 6. Interlacing displacement
    totalDisplacement += interlaceDisplacement(uv, effectiveTime, glitch);

    // Apply accumulated displacement
    float2 displacedUV = uv + totalDisplacement;

    // === CHROMATIC ABERRATION WITH DISPLACEMENT ===
    // RGB channels sample from different displaced positions
    float2 redUV, greenUV, blueUV;
    rgbDisplacement(displacedUV, effectiveTime, glitch, audioLevel, redUV, greenUV, blueUV);

    // Sample each color channel from its displaced position
    float r = inputTexture.sample(textureSampler, redUV).r;
    float g = inputTexture.sample(textureSampler, greenUV).g;
    float b = inputTexture.sample(textureSampler, blueUV).b;

    float3 color = float3(r, g, b);

    // === HORIZONTAL TEARING (displacement-based) ===
    // Entire horizontal strips show content from different X positions
    float tearSeed = floor(effectiveTime * 5.0);
    float tearChance = hash(tearSeed);
    if (tearChance > 1.0 - glitch * 0.25) {
        float tearY = hash(tearSeed + 0.1);
        float tearHeight = 0.03 + hash(tearSeed + 0.2) * 0.08;

        if (abs(uv.y - tearY) < tearHeight) {
            // Sample from dramatically offset X position
            float tearOffset = (hash(tearSeed + 0.3) - 0.5) * glitch * 0.5;
            float2 tearUV = float2(uv.x + tearOffset, uv.y) + totalDisplacement;

            // Apply RGB split to torn area too
            float2 tearRedUV, tearGreenUV, tearBlueUV;
            rgbDisplacement(tearUV, effectiveTime, glitch * 1.5, audioLevel, tearRedUV, tearGreenUV, tearBlueUV);

            color.r = inputTexture.sample(textureSampler, tearRedUV).r;
            color.g = inputTexture.sample(textureSampler, tearGreenUV).g;
            color.b = inputTexture.sample(textureSampler, tearBlueUV).b;
        }
    }

    // === COLOR CHANNEL SWAP (occasional) ===
    float swapChance = hash(floor(effectiveTime * 4.0) + floor(uv.y * 15.0));
    if (swapChance > 1.0 - glitch * 0.2) {
        int swapType = int(hash(floor(effectiveTime * 5.0)) * 6.0);
        switch (swapType) {
            case 0: color = color.rbg; break;
            case 1: color = color.grb; break;
            case 2: color = color.gbr; break;
            case 3: color = color.brg; break;
            case 4: color = color.bgr; break;
            default: break;
        }
    }

    // === SUBTLE SCAN LINES (reduced intensity) ===
    float scanLineIntensity = glitch * 0.15; // Reduced from 0.3
    float scanLine = sin(uv.y * 600.0) * 0.5 + 0.5;
    color *= 1.0 - scanLine * scanLineIntensity;

    // === MINIMAL STATIC NOISE (greatly reduced) ===
    // Only add noise in severely glitched areas, not everywhere
    float staticNoise = hash(uv * 800.0 + effectiveTime * 80.0);
    float staticIntensity = glitch * 0.05 * (1.0 + audioLevel * 0.5); // Reduced from 0.15
    float noiseThreshold = hash(floor(effectiveTime * 12.0));
    if (noiseThreshold > 1.0 - glitch * 0.15) {
        color = mix(color, float3(staticNoise), staticIntensity);
    }

    // === BRIGHTNESS FLICKER ===
    float flicker = 1.0 + (hash(floor(effectiveTime * 12.0)) - 0.5) * glitch * 0.25;
    color *= flicker;

    // === SIGNAL DROPOUT (black bands) ===
    // Occasional complete signal loss in horizontal bands
    float dropoutSeed = floor(effectiveTime * 3.0);
    float dropoutChance = hash(dropoutSeed);
    if (dropoutChance > 1.0 - glitch * 0.1) {
        float dropoutY = hash(dropoutSeed + 0.5);
        float dropoutHeight = 0.01 + hash(dropoutSeed + 0.7) * 0.03;
        if (abs(uv.y - dropoutY) < dropoutHeight) {
            color *= 0.1; // Near-black, simulating signal loss
        }
    }

    // Clamp final output
    color = clamp(color, 0.0, 1.0);

    return float4(color, 1.0);
}
