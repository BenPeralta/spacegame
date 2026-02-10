#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

// Vertex Shader Output
struct RasterizerData
{
    float4 position [[position]];
    float4 color;
    float2 localCoord; // For SDF circle drawing (-1 to 1)
    float radius;
    float glow;
    float seed;
};



// MARK: - Noise Functions

float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    // Cubic Hermite Interpolation
    float2 u = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i + float2(0.0, 0.0));
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

#define NUM_OCTAVES 3

float fbm(float2 x) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0);
    // Rotate to reduce axial bias
    float2x2 rot = float2x2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
    for (int i = 0; i < NUM_OCTAVES; ++i) {
        v += a * noise(x);
        x = rot * x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// Quad vertex data for instancing
constant float2 quadVertices[] = {
    float2(-1, -1),
    float2( 1, -1),
    float2(-1,  1),
    float2( 1,  1)
};

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             uint instanceID [[instance_id]],
             constant InstanceData *instances [[buffer(VertexInputIndexInstances)]],
             constant Uniforms &uniforms [[buffer(VertexInputIndexUniforms)]])
{
    RasterizerData out;
    
    // Get instance data
    InstanceData instance = instances[instanceID];
    
    // Get quad vertex position
    float2 quadPos = quadVertices[vertexID]; // -1 to 1
    
    // Scale by radius
    float2 localPos = quadPos * instance.radius;
    
    // Translate by world position
    float2 worldPos = instance.position + localPos;
    
    // Apply Camera (Translation)
    float2 camRelPos = (worldPos - uniforms.cameraPosition);
    
    // Apply Zoom
    float2 viewPos = camRelPos * uniforms.zoomLevel;
    
    // Normalize to clip space (-1 to 1) using viewport size
    // Note: Metal clip space is -1..1 for x and y, and 0..1 for z (we ignore z)
    // We assume 2D orthographic projection centered at 0,0
    float2 clipPos;
    clipPos.x = viewPos.x / (uniforms.viewportSize.x * 0.5);
    clipPos.y = viewPos.y / (uniforms.viewportSize.y * 0.5); // Y-flip if needed handled by MTKView or view matrix
    // Flip Y because Metal is top-left or bottom-left depending, usually -1,-1 is bottom left.
    // Let's assume standard math coords where +y is up.
    
    out.position = float4(clipPos.x, clipPos.y, 0.0, 1.0);
    out.color = instance.color;
    out.localCoord = quadPos; // Pass the -1..1 coord for SDF
    out.radius = instance.radius;
    out.glow = instance.glowIntensity;
    out.seed = instance.seed;
    
    return out;
}

fragment float4
fragmentShader(RasterizerData in [[stage_in]])
{
    float dist = length(in.localCoord);
    
    // 1. Circle Crop
    if (dist > 1.0) discard_fragment();
    
    // 2. 3D Sphere Normal
    float z = sqrt(max(0.0, 1.0 - dist*dist));
    float3 normal = float3(in.localCoord.x, -in.localCoord.y, z);
    
    // 3. Lighting
    float3 lightDir = normalize(float3(-0.5, 0.5, 0.8));
    float diffuse = max(0.0, dot(normal, lightDir));
    
    // 4. SURFACE GENERATION (Procedural Texture based on Input Color)
    // We use the color passed from Swift (in.color) as the base, and apply noise for texture.
    // This allows World.swift to control the color logic (Gray vs Green vs Orange).
    
    float3 inputColor = in.color.rgb; // Base color from Swift
    float3 darkColor = inputColor * 0.4; // Shadow/Crater color
    float3 lightColor = inputColor * 1.2; // Highlight color
    
    float3 baseCol;
    float specStrength = 0.1;
    
    // OPTIMIZATION: Skip expensive FBM only for TINY particles (not fragments!)
    if (in.radius < 5.0) {
        // Fast path: simple hash-based variation
        float simpleNoise = hash(in.localCoord + float2(in.seed));
        baseCol = mix(inputColor, lightColor, simpleNoise * 0.3);
        specStrength = 0.05;
    } else {
        // Full detail path for visible objects
        float n = fbm(in.localCoord * 2.5 + float2(in.seed * 17.0, in.seed * -5.0));
    
    if (in.radius < 38.0) {
        // SMALL ROCKS / ASTEROIDS / METEORS (More noise, rougher)
        float nRock = fbm(in.localCoord * 4.0);
        baseCol = mix(darkColor, inputColor, smoothstep(0.2, 0.8, nRock));
        specStrength = 0.05;
    } else {
        // PLANETS - Realistic solar system patterns
        if (in.radius > 100.0) {  // Gas Giants (Jupiter/Saturn style)
            // Banded patterns
            float bands = sin(in.localCoord.y * 15.0 + fbm(in.localCoord * 2.0) * 3.0) * 0.5 + 0.5;
            float3 bandCol1 = float3(0.9, 0.7, 0.5);  // Jupiter orange/brown
            float3 bandCol2 = float3(0.8, 0.8, 0.9);  // Saturn pale
            baseCol = mix(bandCol1, bandCol2, bands);
            
            // Great Red Spot-like storm (random seed)
            if (fract(in.seed) > 0.5) {
                float storm = length(in.localCoord - float2(0.2, -0.1));
                if (storm < 0.15) baseCol = float3(0.8, 0.3, 0.2);  // Red spot
            }
            specStrength = 0.1;
        } else if (in.radius > 60.0) {  // Ice Giants (Uranus/Neptune)
            baseCol = float3(0.6, 0.8, 0.9);  // Pale blue
            float haze = fbm(in.localCoord * 5.0);
            baseCol = mix(baseCol, float3(0.8, 0.9, 1.0), haze * 0.4);  // Misty
            specStrength = 0.2;
        } else {  // Terrestrial (Mercury, Venus, Earth, Mars)
            float patternSeed = fract(in.seed * 543.21);
            if (in.radius < 50.0) {  // Small rocky (Mercury/Mars)
                baseCol = mix(float3(0.6, 0.3, 0.2), float3(0.7, 0.7, 0.7), n);  // Red/gray craters
                specStrength = 0.05;
            } else if (patternSeed < 0.4) {  // Earth-like (blue/green continents)
                float land = smoothstep(0.4, 0.6, n);
                baseCol = mix(float3(0.0, 0.2, 0.6), float3(0.1, 0.6, 0.2), land);  // Ocean/land
                // Clouds
                float clouds = fbm(in.localCoord * 8.0);
                baseCol = mix(baseCol, float3(1.0, 1.0, 1.0), clouds * 0.3);
                specStrength = 0.5;
            } else {  // Venus-like (yellow clouds)
                baseCol = float3(0.9, 0.8, 0.5);
                float clouds = fbm(in.localCoord * 6.0);
                baseCol = mix(baseCol * 0.8, float3(1.0, 0.9, 0.7), clouds);
                specStrength = 0.1;
            }
        }
    }
    } // End detailed rendering path

    // Apply Lighting
    // Boosted Ambient from 0.05 to 0.3 for visibility
    float3 finalCol = baseCol * (0.3 + 0.8 * diffuse); 
    
    // Specular
    float3 viewDir = float3(0,0,1);
    float3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(0.0, dot(viewDir, reflectDir)), 12.0);
    finalCol += float3(1.0) * spec * specStrength;
    
    // Atmosphere / Rim
    float rim = 1.0 - max(0.0, dot(normal, viewDir));
    rim = pow(rim, 4.0);
    
    // Stronger Rim for visibility against dark background
    float3 atmColor = baseCol + float3(0.2);
    finalCol += atmColor * rim * 1.5; // Boosted Rim
    
    if (in.glow > 0.0) {
        finalCol += in.color.rgb * in.glow * rim;
    }
    
    // Edge AA
    float delta = fwidth(dist);
    float alpha = 1.0 - smoothstep(1.0 - delta, 1.0, dist);
    
    return float4(finalCol, in.color.a * alpha);
}

// MARK: - Background Shaders

struct StarVertexIn {
    float2 position;
    float4 color;
    float size;
    float depth;
};

struct StarOut {
    float4 position [[position]];
    float4 color;
    float size [[point_size]];
    float2 uv;
};

vertex StarOut
backgroundVertexShader(uint vertexID [[vertex_id]],
                       constant StarVertexIn *stars [[buffer(0)]],
                       constant Uniforms &uniforms [[buffer(1)]])
{
    StarOut out;
    StarVertexIn star = stars[vertexID];
    
    float parallaxFactor = (1.0 - star.depth * 0.8);
    float2 parallaxPos = star.position - (uniforms.cameraPosition * parallaxFactor);
    
    float wrapSize = 8000.0;
    float halfSize = 4000.0;
    float2 distFromCam = parallaxPos; 
    
    if (distFromCam.x > halfSize) distFromCam.x -= wrapSize;
    if (distFromCam.x < -halfSize) distFromCam.x += wrapSize;
    if (distFromCam.y > halfSize) distFromCam.y -= wrapSize;
    if (distFromCam.y < -halfSize) distFromCam.y += wrapSize;
    
    // Apply zoom
    float2 viewPos = distFromCam * uniforms.zoomLevel;
    
    // Clip space
    float2 clipPos;
    clipPos.x = viewPos.x / (uniforms.viewportSize.x * 0.5);
    clipPos.y = viewPos.y / (uniforms.viewportSize.y * 0.5);
    
    out.position = float4(clipPos.x, clipPos.y, 0.9, 1.0);
    out.color = star.color;
    out.size = star.size * uniforms.zoomLevel;
    
    // Pass UV for Nebula? Actually nebula needs screen space UV
    // But we are drawing POINTS here. Nebula must be a full screen quad or drawn behind stars?
    // Current architectue draws STARS as points.
    // If we want a nebula layer, we need a separate draw call for a full screen quad.
    // OR... we can just hack it by drawing a HUGE point behind everything?
    // Let's rely on BackgroundRenderer drawing a quad first?
    // Current implementation: BackgroundRenderer draws STARS using this shader.
    // To add nebula, we should modify BackgroundRenderer to draw a quad first.
    // For now, let's keep stars bright.
    
    return out;
}

fragment float4
backgroundFragmentShader(StarOut in [[stage_in]], float2 pointCoord [[point_coord]])
{
    float2 coord = pointCoord * 2.0 - 1.0;
    float dist = length(coord);
    if (dist > 1.0) discard_fragment();
    float alpha = 1.0 - smoothstep(0.1, 1.0, dist);
    return float4(in.color.rgb, in.color.a * alpha);
}

// NEBULA SHADER (New)
// We need a fullscreen quad shader for the background nebula
struct NebulaOut {
    float4 position [[position]];
    float2 uv;
};

vertex NebulaOut nebulaVertex(uint vertexID [[vertex_id]],
                              constant Uniforms &uniforms [[buffer(1)]])
{
    NebulaOut out;
    float2 quadVertices[] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1)
    };
    out.position = float4(quadVertices[vertexID], 1.0, 1.0); // Depth 1.0 (Furthest)
    
    // UV logic: Screen space to World space
    // uv = (position + camera) / scale
    float2 worldPos = (out.position.xy * 0.5 * uniforms.viewportSize / uniforms.zoomLevel) + uniforms.cameraPosition * 0.3; // Parallax 0.3
    out.uv = worldPos * 0.0005; // Scale down for large noise
    return out;
}

fragment float4 nebulaFragment(NebulaOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]])
{
    float2 uv = in.uv;
    
    // Layer 1: Purple/Blue FBM
    float n1 = fbm(uv + float2(uniforms.time * 0.01, 0));
    float3 col1 = float3(0.1, 0.0, 0.2); // Purple
    float3 col2 = float3(0.0, 0.1, 0.3); // Blue
    
    float3 nebula = mix(col1, col2, n1);
    
    // Layer 2: Bright Dust
    float n2 = fbm(uv * 2.0 - float2(0, uniforms.time * 0.015));
    float bright = smoothstep(0.4, 0.8, n2);
    nebula += float3(0.4, 0.3, 0.1) * bright * 0.3; // Gold dust
    
    // Base space color (not black)
    float3 space = float3(0.01, 0.01, 0.02);
    
    return float4(space + nebula * 0.5, 1.0);
}

