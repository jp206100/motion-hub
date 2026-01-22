//
//  ShaderTypes.h
//  Motion Hub
//
//  Shared types between Swift and Metal shaders
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Shader uniforms passed to all shaders
struct Uniforms {
    float time;              // Seconds since start
    float deltaTime;         // Frame delta

    // Audio
    float audioLevel;        // Overall level
    float audioBass;         // Low freq
    float audioMid;          // Mid freq
    float audioHigh;         // High freq
    float audioFreqBand;     // User-selected band level

    // Controls
    float intensity;         // 0-1
    float glitchAmount;      // 0-1
    float speed;             // 1-4 multiplier
    float colorShift;        // 0-1
    int isMonochrome;        // 0 or 1

    // Resolution
    simd_float2 resolution;

    // Random seed for reset
    uint32_t randomSeed;
};

// Vertex output
struct VertexOut {
    simd_float4 position [[position]];
    simd_float2 texCoord;
};

#endif /* ShaderTypes_h */
