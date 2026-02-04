//
//  ShaderTypes.h
//  Motion Hub
//
//  Shared types between Swift and Metal shaders
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Maximum number of inspiration textures that can be active
#define MAX_TEXTURES 8

// Shader uniforms passed to all shaders
struct Uniforms {
    float time;              // Seconds since start
    float deltaTime;         // Frame delta

    // Audio - expanded for better reactivity
    float audioLevel;        // Overall level
    float audioBass;         // Low freq (20-250 Hz)
    float audioMid;          // Mid freq (250-2000 Hz)
    float audioHigh;         // High freq (2000-20000 Hz)
    float audioFreqBand;     // User-selected band level
    float audioPeak;         // Peak detection for transients
    float audioSmooth;       // Smoothed overall level

    // Controls
    float intensity;         // 0-1 (affects saturation and visual intensity)
    float glitchAmount;      // 0-1 (controls glitch probability and severity)
    float speed;             // 1-4 multiplier
    float colorShift;        // 0-1
    float pulseStrength;     // 0-1 (how strongly visuals respond to audio beats)
    int isMonochrome;        // 0 or 1

    // Resolution
    simd_float2 resolution;

    // Random seed for reset - determines visual pattern
    uint32_t randomSeed;

    // Texture info
    int32_t textureCount;    // Number of active inspiration textures
    int32_t activePattern;   // Which procedural pattern to use (0-7)

    // Glitch timing for stutter effect
    float lastGlitchTime;    // When the last major glitch occurred
    float glitchHoldTime;    // How long to hold a frozen frame
};

// Vertex output
struct VertexOut {
    simd_float4 position [[position]];
    simd_float2 texCoord;
};

// Color palette passed from inspiration pack
struct ColorPalette {
    simd_float4 colors[6];   // Up to 6 colors per palette
    int colorCount;
};

#endif /* ShaderTypes_h */
