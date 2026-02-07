//
//  BaseLayer.metal
//  Motion Hub
//
//  Base layer shader - Multiple generative visual patterns
//  Pattern selection based on randomSeed for variety
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations from Common.metal
float hash(float2 p);
float3 hash3(float2 p);
float noise(float2 p);
float gradientNoise(float2 p);
float fbm(float2 p, int octaves);
float voronoi(float2 p);
float simplexNoise(float2 p);
float3 rgb2hsv(float3 c);
float3 hsv2rgb(float3 c);
float pulse(float t, float freq, float sharpness);
float2 kaleidoscope(float2 uv, float segments);

// MARK: - Palette Helper
// Maps a 0-1 value to a color from the inspiration pack palette (with fallback)
float3 paletteColor(float t, constant ColorPalette* palettes,
                     float3 fallback1, float3 fallback2, float3 fallback3) {
    if (palettes != nullptr && palettes[0].colorCount >= 3) {
        ColorPalette pal = palettes[0];
        float idx = t * float(pal.colorCount - 1);
        int i0 = clamp(int(floor(idx)), 0, pal.colorCount - 1);
        int i1 = clamp(i0 + 1, 0, pal.colorCount - 1);
        float frac = idx - floor(idx);
        return mix(pal.colors[i0].rgb, pal.colors[i1].rgb, frac);
    }
    // Fallback to hardcoded colors
    if (t < 0.5) return mix(fallback3, fallback1, t * 2.0);
    return mix(fallback1, fallback2, (t - 0.5) * 2.0);
}

// MARK: - Pattern 0: Organic Flow
float3 patternOrganicFlow(float2 uv, float t, float audioMod, float intensity,
                           constant ColorPalette* palettes) {
    // Flowing organic shapes using FBM
    float2 p = uv * 3.0;

    // Distort UV based on audio
    p += float2(
        fbm(p + t * 0.3, 4) * audioMod * 2.0,
        fbm(p - t * 0.2 + 100.0, 4) * audioMod * 2.0
    );

    float n = fbm(p + t * 0.1, 5);

    // Audio-reactive pulsation
    float pulsation = 1.0 + audioMod * intensity * 0.8;
    n *= pulsation;

    // Use inspiration pack palette colors (with warm organic fallback)
    float3 color = paletteColor(n,
        palettes,
        float3(0.8, 0.3, 0.2),   // Warm red fallback
        float3(0.9, 0.6, 0.3),   // Orange fallback
        float3(0.2, 0.1, 0.3));  // Deep purple fallback
    color *= 0.5 + n * 0.5 + audioMod * intensity * 0.5;

    return color;
}

// MARK: - Pattern 1: Cellular Division
float3 patternCellular(float2 uv, float t, float audioMod, float intensity,
                        constant ColorPalette* palettes) {
    // Voronoi-based cellular pattern
    float2 p = uv * 5.0;

    // Animate cell positions
    p += t * 0.2;

    // Audio makes cells pulse
    float scale = 5.0 + audioMod * intensity * 3.0;
    float v = voronoi(uv * scale);
    float v2 = voronoi(uv * scale * 2.0 + 10.0);

    // Edge detection on cells - combine both voronoi layers
    float edge = smoothstep(0.0, 0.1 + audioMod * 0.1, v * 0.7 + v2 * 0.3);

    // Use inspiration palette if available
    float colorVal = fract(v * 0.5 + t * 0.1);
    float3 color;
    if (palettes != nullptr && palettes[0].colorCount >= 2) {
        color = paletteColor(colorVal, palettes,
            float3(0.3, 0.6, 1.0), float3(0.8, 0.4, 1.0), float3(0.1, 0.2, 0.4));
        color *= edge * (0.6 + audioMod * intensity * 0.4);
    } else {
        float hue = colorVal;
        float sat = 0.7 + audioMod * intensity * 0.3;
        float val = edge * (0.6 + audioMod * intensity * 0.4);
        color = hsv2rgb(float3(hue, sat, val));
    }

    // Add glow at edges using palette accent color
    float glow = 1.0 - smoothstep(0.0, 0.15, v);
    float3 glowColor = (palettes != nullptr && palettes[0].colorCount > 0)
        ? palettes[0].colors[0].rgb : float3(0.3, 0.6, 1.0);
    color += glowColor * glow * audioMod * intensity;

    return color;
}

// MARK: - Pattern 2: Plasma Waves
float3 patternPlasma(float2 uv, float t, float audioMod, float intensity,
                      constant ColorPalette* palettes) {
    float2 p = uv * 2.0 - 1.0;

    // Multiple plasma waves
    float plasma = 0.0;
    plasma += sin(p.x * 10.0 + t * 2.0);
    plasma += sin(p.y * 10.0 + t * 1.7);
    plasma += sin((p.x + p.y) * 8.0 + t * 2.5);
    plasma += sin(length(p) * 12.0 - t * 3.0);

    // Audio modulates wave intensity
    plasma *= 0.25;
    plasma += audioMod * intensity * sin(t * 5.0 + length(p) * 10.0);

    // Pulsating brightness
    float brightness = 0.5 + audioMod * intensity * 0.5;

    // Use inspiration palette to color the plasma
    float plasmaT = plasma * 0.5 + 0.5;  // Normalize to 0-1
    float3 color;
    if (palettes != nullptr && palettes[0].colorCount >= 2) {
        color = paletteColor(fract(plasmaT + t * 0.05), palettes,
            float3(1.0, 0.3, 0.3), float3(0.3, 0.3, 1.0), float3(0.3, 1.0, 0.3));
    } else {
        color.r = sin(plasma * 3.14159 + 0.0) * 0.5 + 0.5;
        color.g = sin(plasma * 3.14159 + 2.094) * 0.5 + 0.5;
        color.b = sin(plasma * 3.14159 + 4.188) * 0.5 + 0.5;
    }

    color *= brightness;

    return color;
}

// MARK: - Pattern 3: Kaleidoscope
float3 patternKaleidoscope(float2 uv, float t, float audioMod, float intensity,
                            constant ColorPalette* palettes) {
    // Number of segments varies with audio
    float segments = 6.0 + floor(audioMod * intensity * 4.0);

    // Apply kaleidoscope fold
    float2 kUv = kaleidoscope(uv, segments);

    // Rotate over time
    float2 centered = kUv * 2.0 - 1.0;
    float angle = t * 0.5;
    float2 rotated;
    rotated.x = centered.x * cos(angle) - centered.y * sin(angle);
    rotated.y = centered.x * sin(angle) + centered.y * cos(angle);
    rotated = rotated * 0.5 + 0.5;

    // Create pattern
    float n = fbm(rotated * 4.0 + t * 0.2, 4);
    n += audioMod * intensity * 0.5;

    // Use palette for kaleidoscope coloring
    float3 color;
    if (palettes != nullptr && palettes[0].colorCount >= 2) {
        color = paletteColor(fract(n + t * 0.1), palettes,
            float3(1.0, 0.0, 0.5), float3(0.5, 0.0, 1.0), float3(0.0, 0.5, 1.0));
        color *= 0.4 + n * 0.4 + audioMod * intensity * 0.3;
    } else {
        float hue = fract(n + t * 0.1);
        float sat = 0.8;
        float val = 0.4 + n * 0.4 + audioMod * intensity * 0.3;
        color = hsv2rgb(float3(hue, sat, val));
    }

    return color;
}

// MARK: - Pattern 4: Digital Grid
float3 patternDigitalGrid(float2 uv, float t, float audioMod, float intensity,
                           constant ColorPalette* palettes) {
    // Grid-based digital pattern
    float gridSize = 20.0 + audioMod * intensity * 10.0;
    float2 grid = fract(uv * gridSize);
    float2 gridId = floor(uv * gridSize);

    // Random activation per cell
    float activation = hash(gridId + floor(t * 4.0));
    activation = step(0.7 - audioMod * intensity * 0.5, activation);

    // Cell glow
    float2 cellCenter = grid - 0.5;
    float dist = length(cellCenter);
    float glow = 1.0 - smoothstep(0.0, 0.5, dist);
    glow *= activation;

    // Pulsing effect
    glow *= 0.5 + 0.5 * sin(t * 10.0 + hash(gridId) * 6.28);
    glow *= 1.0 + audioMod * intensity;

    // Use palette colors for grid (with cyberpunk fallback)
    float colorMix = hash(gridId * 2.0);
    float3 color1, color2;
    if (palettes != nullptr && palettes[0].colorCount >= 2) {
        color1 = palettes[0].colors[0].rgb;
        color2 = palettes[0].colors[min(1, palettes[0].colorCount - 1)].rgb;
    } else {
        color1 = float3(0.0, 1.0, 0.8);  // Cyan
        color2 = float3(1.0, 0.0, 0.5);  // Magenta
    }

    float3 color = mix(color1, color2, colorMix) * glow;

    // Add scan lines
    float scanLine = sin(uv.y * 200.0 + t * 10.0) * 0.5 + 0.5;
    color *= 0.8 + scanLine * 0.2;

    return color;
}

// MARK: - Pattern 5: Fluid Simulation
float3 patternFluid(float2 uv, float t, float audioMod, float intensity,
                     constant ColorPalette* palettes) {
    float2 p = uv * 2.0 - 1.0;

    // Domain warping for fluid effect
    float2 q = float2(
        fbm(p + t * 0.1, 4),
        fbm(p + float2(1.0, 0.0), 4)
    );

    float2 r = float2(
        fbm(p + q * 4.0 + float2(1.7, 9.2) + t * 0.15, 4),
        fbm(p + q * 4.0 + float2(8.3, 2.8) + t * 0.126, 4)
    );

    float f = fbm(p + r * 4.0 + audioMod * intensity * 2.0, 4);

    // Use inspiration palette for fluid coloring
    float3 color;
    if (palettes != nullptr && palettes[0].colorCount >= 3) {
        color = paletteColor(clamp(f, 0.0, 1.0), palettes,
            float3(0.2, 0.4, 0.6), float3(0.4, 0.7, 0.9), float3(0.1, 0.2, 0.4));
    } else {
        float3 col1 = float3(0.1, 0.2, 0.4);
        float3 col2 = float3(0.2, 0.4, 0.6);
        float3 col3 = float3(0.4, 0.7, 0.9);
        float3 col4 = float3(0.9, 0.9, 1.0);
        color = mix(col1, col2, clamp(f * 2.0, 0.0, 1.0));
        color = mix(color, col3, clamp(f * 2.0 - 0.5, 0.0, 1.0));
        color = mix(color, col4, clamp(f * 2.0 - 1.0, 0.0, 1.0));
    }

    // Audio brightness pulse
    color *= 0.6 + audioMod * intensity * 0.6;

    return color;
}

// MARK: - Pattern 6: Particle Field
float3 patternParticles(float2 uv, float t, float audioMod, float intensity,
                         constant ColorPalette* palettes) {
    float3 color = float3(0.02, 0.02, 0.05);

    // Multiple particle layers
    for (int layer = 0; layer < 3; layer++) {
        float layerScale = 1.0 + float(layer) * 0.5;
        float layerSpeed = 1.0 + float(layer) * 0.3;

        for (int i = 0; i < 20; i++) {
            // Particle position
            float2 particleId = float2(float(i), float(layer));
            float3 rnd = hash3(particleId);

            float2 pos;
            pos.x = fract(rnd.x + t * 0.1 * layerSpeed * (rnd.z - 0.5));
            pos.y = fract(rnd.y + t * 0.05 * layerSpeed);

            // Distance to particle
            float dist = length(uv - pos);

            // Particle size pulsates with audio
            float size = 0.01 + audioMod * intensity * 0.02;
            size *= (1.0 + sin(t * 5.0 + rnd.z * 6.28) * 0.3);

            // Glow
            float glow = size / (dist + 0.001);
            glow = pow(glow, 1.5);

            // Use palette colors for particles
            float3 particleColor;
            if (palettes != nullptr && palettes[0].colorCount > 0) {
                int cIdx = (i + layer) % palettes[0].colorCount;
                particleColor = palettes[0].colors[cIdx].rgb;
            } else {
                particleColor = hsv2rgb(float3(rnd.z + t * 0.1, 0.8, 1.0));
            }
            color += particleColor * glow * 0.02 / layerScale;
        }
    }

    return color;
}

// MARK: - Pattern 7: Fractal Zoom
float3 patternFractalZoom(float2 uv, float t, float audioMod, float intensity,
                           constant ColorPalette* palettes) {
    float2 p = uv * 2.0 - 1.0;

    // Zoom effect
    float zoom = 2.0 + sin(t * 0.5) * 0.5 + audioMod * intensity;
    p *= zoom;

    // Rotate
    float angle = t * 0.2;
    float2 rotP;
    rotP.x = p.x * cos(angle) - p.y * sin(angle);
    rotP.y = p.x * sin(angle) + p.y * cos(angle);

    // Mandelbrot-inspired iteration
    float2 z = rotP;
    float2 c = float2(-0.7 + sin(t * 0.1) * 0.1, 0.27 + cos(t * 0.15) * 0.1);

    float iterations = 0.0;
    for (int i = 0; i < 50; i++) {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (length(z) > 4.0) break;
        iterations += 1.0;
    }

    // Color based on iterations using palette
    float n = iterations / 50.0;
    n = pow(n, 0.5);

    float3 color;
    if (palettes != nullptr && palettes[0].colorCount >= 2) {
        color = paletteColor(fract(n * 2.0 + t * 0.1), palettes,
            float3(0.8, 0.2, 0.5), float3(0.2, 0.5, 0.8), float3(0.1, 0.1, 0.2));
        color *= n * (0.5 + audioMod * intensity * 0.5);
    } else {
        float hue = fract(n * 2.0 + t * 0.1);
        float sat = 0.8 - n * 0.3;
        float val = n * (0.5 + audioMod * intensity * 0.5);
        color = hsv2rgb(float3(hue, sat, val));
    }

    return color;
}

// MARK: - Main Fragment Shader
fragment float4 baseLayerFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    constant ColorPalette* palettes [[buffer(1)]]
) {
    float2 uv = in.texCoord;
    float t = u.time * u.speed * 0.3;

    // Audio modulation - pulseStrength controls beat response, intensity controls overall visual intensity
    float audioMod = u.audioFreqBand;
    float bassBoost = u.audioBass * 2.0;  // Stronger bass boost
    float intensity = u.intensity;
    float pulse = u.pulseStrength;

    // Select pattern based on randomSeed
    int pattern = u.activePattern % 8;

    float3 color;

    switch (pattern) {
        case 0:
            color = patternOrganicFlow(uv, t, audioMod, intensity, palettes);
            break;
        case 1:
            color = patternCellular(uv, t, audioMod, intensity, palettes);
            break;
        case 2:
            color = patternPlasma(uv, t, audioMod, intensity, palettes);
            break;
        case 3:
            color = patternKaleidoscope(uv, t, audioMod, intensity, palettes);
            break;
        case 4:
            color = patternDigitalGrid(uv, t, audioMod, intensity, palettes);
            break;
        case 5:
            color = patternFluid(uv, t, audioMod, intensity, palettes);
            break;
        case 6:
            color = patternParticles(uv, t, audioMod, intensity, palettes);
            break;
        case 7:
        default:
            color = patternFractalZoom(uv, t, audioMod, intensity, palettes);
            break;
    }

    // Global audio-reactive pulsation - pulse controls beat response strength
    // Higher multipliers (0.8) for more dramatic beat response
    float globalPulse = 1.0 + (bassBoost + audioMod) * pulse * 0.8;
    color *= globalPulse;

    // Additional brightness flash on strong beats (using audioPeak for transients)
    float beatFlash = u.audioPeak * pulse * 0.5;
    color += color * beatFlash;

    // Subtle screen-wide breathing effect tied to audio
    float breathing = 1.0 + sin(t * 2.0) * audioMod * pulse * 0.3;
    color *= breathing;

    // Monochrome mode
    if (u.isMonochrome) {
        float luma = dot(color, float3(0.299, 0.587, 0.114));
        color = float3(luma);
    }

    // Clamp to valid range
    color = clamp(color, 0.0, 1.0);

    return float4(color, 1.0);
}
