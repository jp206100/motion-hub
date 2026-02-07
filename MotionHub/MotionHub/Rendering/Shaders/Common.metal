//
//  Common.metal
//  Motion Hub
//
//  Common shader functions and utilities
//

#include <metal_stdlib>
#include "../ShaderTypes.h"

using namespace metal;

// Forward declarations for color space conversions
float3 rgb2hsv(float3 c);
float3 hsv2rgb(float3 c);

// MARK: - Simple Test Fragment Shader (for debugging)
// This shader has minimal dependencies to test if pipelines work
fragment float4 simpleTestFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    // Output yellow gradient to distinguish from other test colors
    return float4(uv.x, uv.y, 0.0, 1.0);
}

// MARK: - Simple Test WITH Texture parameter (for debugging)
// Tests if adding a texture parameter breaks the shader
fragment float4 simpleTestWithTextureFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> inputTexture [[texture(0)]]
) {
    float2 uv = in.texCoord;
    // Output orange gradient - ignores texture completely
    return float4(1.0, uv.x * 0.5, 0.0, 1.0);
}

// MARK: - Working Composite Shader (for Pass 2)
// This passes through the base texture with audio-reactive effects
fragment float4 workingCompositeFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> baseTexture [[texture(0)]]
) {
    constexpr sampler clampSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    float2 uv = in.texCoord;
    float pulse = u.pulseStrength;

    // Sample base texture
    float4 baseColor = baseTexture.sample(clampSampler, uv);

    // Audio-reactive brightness pulse - stronger effect using pulseStrength
    // Bass creates the main "thump" feel with up to 80% brightness increase at max pulse
    float bassPulse = 1.0 + u.audioBass * pulse * 0.8;
    baseColor.rgb *= bassPulse;

    // Mid frequencies add saturation boost for punch
    float midBoost = u.audioMid * pulse * 0.4;
    float3 hsv = rgb2hsv(baseColor.rgb);
    hsv.y = min(1.0, hsv.y * (1.0 + midBoost));
    baseColor.rgb = hsv2rgb(hsv);

    // High frequencies add sparkle/glow
    float highGlow = u.audioHigh * pulse * 0.2;
    baseColor.rgb += baseColor.rgb * highGlow;

    // Peak detection flash for transients (drum hits, etc.)
    float peakFlash = u.audioPeak * pulse * 0.3;
    baseColor.rgb += float3(peakFlash);

    return baseColor;
}

// MARK: - Inspiration Blend Shader (for Pass 2 with inspiration packs)
// Deconstructs inspiration textures into the procedural base layer
// Six layered techniques: UV displacement, kaleidoscope fragmentation, edge glow,
// slit-scan ribbons, luminance masking, and beat-triggered reveals
// Must live in Common.metal because TextureComposite.metal is not in the Xcode build target

// Screen blend - always brightens or maintains brightness
static float3 tcBlendScreen(float3 base, float3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

// Ken Burns style slow pan/zoom for brief recognizable reveals
static float2 tcKenBurns(float2 uv, float time, float seed) {
    float panX = sin(time * 0.15 + seed * 3.14) * 0.15;
    float panY = cos(time * 0.12 + seed * 2.17) * 0.1;
    float zoom = 0.7 + sin(time * 0.08 + seed * 1.37) * 0.1;
    float2 center = float2(0.5 + panX, 0.5 + panY);
    return center + (uv - 0.5) * zoom;
}

// Luminance helper
static float tcLuma(float3 c) {
    return dot(c, float3(0.299, 0.587, 0.114));
}

fragment float4 inspirationBlendFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> baseTexture [[texture(0)]],
    texture2d<float> inspirationTex [[texture(1)]]
) {
    constexpr sampler clampSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    constexpr sampler repeatSampler(mag_filter::linear, min_filter::linear, address::repeat);

    float2 uv = in.texCoord;
    float t = u.time * u.speed * 0.2;
    float pulse = u.pulseStrength;
    float intensity = u.intensity;

    // =====================================================
    // TECHNIQUE 1: UV DISPLACEMENT
    // Texture luminance warps the procedural base layer
    // Brand shapes become invisible topography
    // =====================================================
    float2 dispUV = uv + float2(sin(t * 0.3) * 0.12, cos(t * 0.2) * 0.08);
    float dispLuma = tcLuma(inspirationTex.sample(clampSampler, dispUV).rgb);

    float dispAmount = 0.04 * intensity * (1.0 + u.audioBass * pulse * 1.5);
    float2 displaced = uv + (dispLuma - 0.5) * dispAmount;

    float4 baseColor = baseTexture.sample(clampSampler, displaced);
    float3 result = baseColor.rgb;

    // =====================================================
    // TECHNIQUE 2: KALEIDOSCOPIC FRAGMENTATION
    // Texture folded into symmetrical abstract mandala
    // Logos/faces become geometric patterns
    // =====================================================
    float2 centered = uv * 2.0 - 1.0;
    float kAngle = atan2(centered.y, centered.x) + t * 0.3;
    float kRadius = length(centered);

    float segments = 6.0 + floor(u.audioMid * pulse * 4.0);
    float segAngle = 6.28318 / segments;
    kAngle = abs(fmod(kAngle, segAngle) - segAngle * 0.5);

    float2 kaleidoUV = float2(cos(kAngle), sin(kAngle)) * kRadius * 0.6 + 0.5;
    kaleidoUV += float2(t * 0.04, t * 0.025);
    float3 kaleidoColor = inspirationTex.sample(repeatSampler, kaleidoUV).rgb;

    // Kaleidoscope fades in and out on a ~15s cycle
    float kaleidoWeight = (sin(t * 0.42) * 0.5 + 0.5) * 0.3 * intensity;
    result = mix(result, kaleidoColor, kaleidoWeight);

    // =====================================================
    // TECHNIQUE 3: EDGE / CONTOUR GLOW
    // Extract edges from texture → neon structural overlay
    // Brand outlines glow over the procedural layer
    // =====================================================
    float2 edgeUV = uv + float2(sin(t * 0.15) * 0.1, cos(t * 0.1) * 0.08);
    float eps = 0.004;
    float lumC = tcLuma(inspirationTex.sample(clampSampler, edgeUV).rgb);
    float lumR = tcLuma(inspirationTex.sample(clampSampler, edgeUV + float2(eps, 0)).rgb);
    float lumL = tcLuma(inspirationTex.sample(clampSampler, edgeUV - float2(eps, 0)).rgb);
    float lumU = tcLuma(inspirationTex.sample(clampSampler, edgeUV + float2(0, eps)).rgb);
    float lumD = tcLuma(inspirationTex.sample(clampSampler, edgeUV - float2(0, eps)).rgb);

    float edgeH = lumR - lumL;
    float edgeV = lumU - lumD;
    float edge = smoothstep(0.04, 0.25, sqrt(edgeH * edgeH + edgeV * edgeV));

    // Edge glow colored by the texture itself, amplified by high frequencies
    float3 edgeColor = inspirationTex.sample(clampSampler, edgeUV).rgb;
    float edgeWeight = (cos(t * 0.55) * 0.5 + 0.5) * intensity;
    result += edge * edgeColor * edgeWeight * (0.6 + u.audioHigh * pulse * 2.0);

    // =====================================================
    // TECHNIQUE 4: SLIT-SCAN DECONSTRUCTION
    // Columns sample from time-offset positions
    // Image stretches into flowing ribbons
    // =====================================================
    float scanPhase = t * 0.4;
    float2 slitUV = uv;
    slitUV.x = fract(uv.x + sin(uv.y * 8.0 + scanPhase) * 0.2);
    slitUV.y = fract(uv.y + sin(uv.x * 6.0 + scanPhase * 0.7) * 0.15);
    float3 slitColor = inspirationTex.sample(repeatSampler, slitUV).rgb;

    // Slit-scan appears in horizontal bands that drift
    float bandMask = smoothstep(0.0, 0.15, sin(uv.y * 6.0 + t * 0.3))
                   * smoothstep(0.0, 0.15, sin(uv.x * 4.0 + t * 0.2));
    float slitWeight = (sin(t * 0.7 + 2.0) * 0.5 + 0.5) * 0.2 * intensity * bandMask;
    result = mix(result, slitColor, slitWeight);

    // =====================================================
    // TECHNIQUE 5: LUMINANCE MASKING
    // Base layer brightness controls where texture shows
    // Bright procedural areas reveal texture fragments
    // =====================================================
    float baseLuma = tcLuma(baseColor.rgb);
    float lumaMask = smoothstep(0.3, 0.7, baseLuma);

    float2 lumaUV = uv + float2(t * 0.03, -t * 0.02);
    float3 lumaColor = inspirationTex.sample(clampSampler, lumaUV).rgb;

    float lumaWeight = lumaMask * 0.2 * intensity * (sin(t * 0.35 + 3.0) * 0.5 + 0.5);
    result = mix(result, lumaColor, lumaWeight);

    // =====================================================
    // TECHNIQUE 6: BEAT-TRIGGERED REVEAL
    // On strong beats, briefly flash recognizable source
    // Creates "oh I see it!" associability moments
    // =====================================================
    float beatHit = smoothstep(0.5, 0.85, u.audioPeak) * pulse;
    if (beatHit > 0.01) {
        float2 revealUV = tcKenBurns(uv, t, 0.0);
        float3 revealColor = inspirationTex.sample(clampSampler, revealUV).rgb;
        result = mix(result, revealColor, beatHit * 0.5 * intensity);
    }

    // =====================================================
    // AUDIO REACTIVITY
    // =====================================================
    float bassPulseAmt = 1.0 + u.audioBass * pulse * 0.6;
    result *= bassPulseAmt;

    float3 hsv = rgb2hsv(result);
    hsv.y = clamp(hsv.y + u.audioMid * intensity * 0.25, 0.0, 1.0);
    result = hsv2rgb(hsv);

    float highGlow = u.audioHigh * pulse * 0.15;
    result += result * highGlow;

    result = clamp(result, 0.0, 1.0);

    return float4(result, 1.0);
}

// MARK: - Vertex Shader

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    // Fullscreen quad vertices
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };

    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];

    return out;
}

// MARK: - Improved Hash Functions (eliminates diagonal artifacts)

// Better hash using multiple prime rotations
float hash(float2 p) {
    // Use a more complex hash that doesn't create diagonal patterns
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// 3D hash for volumetric noise
float3 hash3(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// Improved value noise without diagonal artifacts
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    // Quintic interpolation for smoother results
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    // Sample at grid corners with improved hash
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Gradient noise (Perlin-style) - smoother and no diagonal artifacts
float gradientNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    // Quintic smoothing
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    // Random gradients at corners
    float2 ga = hash3(i).xy * 2.0 - 1.0;
    float2 gb = hash3(i + float2(1.0, 0.0)).xy * 2.0 - 1.0;
    float2 gc = hash3(i + float2(0.0, 1.0)).xy * 2.0 - 1.0;
    float2 gd = hash3(i + float2(1.0, 1.0)).xy * 2.0 - 1.0;

    // Dot products with corner vectors
    float va = dot(ga, f);
    float vb = dot(gb, f - float2(1.0, 0.0));
    float vc = dot(gc, f - float2(0.0, 1.0));
    float vd = dot(gd, f - float2(1.0, 1.0));

    return mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y) * 0.5 + 0.5;
}

// Fractal Brownian Motion with improved noise
float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * gradientNoise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

// Voronoi cellular noise
float voronoi(float2 p) {
    float2 n = floor(p);
    float2 f = fract(p);

    float minDist = 1.0;

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 neighbor = float2(float(i), float(j));
            float2 point = hash3(n + neighbor).xy;
            float2 diff = neighbor + point - f;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }

    return minDist;
}

// Simplex-like noise for organic patterns
float simplexNoise(float2 p) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2
    const float K2 = 0.211324865; // (3-sqrt(3))/6

    float2 i = floor(p + (p.x + p.y) * K1);
    float2 a = p - i + (i.x + i.y) * K2;
    float2 o = (a.x > a.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 b = a - o + K2;
    float2 c = a - 1.0 + 2.0 * K2;

    float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    float3 n = h * h * h * h * float3(
        dot(a, hash3(i).xy * 2.0 - 1.0),
        dot(b, hash3(i + o).xy * 2.0 - 1.0),
        dot(c, hash3(i + 1.0).xy * 2.0 - 1.0)
    );

    return dot(n, float3(70.0)) * 0.5 + 0.5;
}

// MARK: - Color Space Conversions

// RGB to HSV
float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// MARK: - Visual Effect Helpers

// Smooth pulsation function
float pulse(float t, float freq, float sharpness) {
    float wave = sin(t * freq * 6.28318);
    return pow(wave * 0.5 + 0.5, sharpness);
}

// Create radial pattern
float radialPattern(float2 uv, float segments, float time) {
    float2 centered = uv * 2.0 - 1.0;
    float angle = atan2(centered.y, centered.x);
    float radius = length(centered);
    return sin(angle * segments + time + radius * 2.0) * 0.5 + 0.5;
}

// Kaleidoscope fold
float2 kaleidoscope(float2 uv, float segments) {
    float2 centered = uv * 2.0 - 1.0;
    float angle = atan2(centered.y, centered.x);
    float radius = length(centered);

    float segmentAngle = 6.28318 / segments;
    angle = abs(fmod(angle, segmentAngle) - segmentAngle * 0.5);

    return float2(cos(angle), sin(angle)) * radius * 0.5 + 0.5;
}
