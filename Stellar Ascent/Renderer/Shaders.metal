#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

// MARK: - Noise Helpers
// Simple pseudo-random noise
float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Value Noise
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion (for clouds/terrain)
float fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0);
    float2x2 rot = float2x2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
    for (int i = 0; i < 5; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// MARK: - Vertex Shader
struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float glow;
    float seed;
    float rotation;
    int type [[flat]]; // "flat" means don't interpolate between vertices
    float radius;
    float time;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              uint instanceID [[instance_id]],
                              constant InstanceData *instances [[buffer(0)]],
                              constant Uniforms &uniforms [[buffer(1)]]) {
    InstanceData instance = instances[instanceID];
    
    // Create a generic quad (billboard)
    float2 quadVertices[] = {
        float2(-1, -1), float2(1, -1),
        float2(-1,  1), float2(1,  1)
    };
    float2 positionOffset = quadVertices[vertexID];
    
    // Scale by radius
    float2 worldPosition = instance.position + positionOffset * instance.radius;
    
    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * float4(worldPosition, 0, 1);
    
    // Map UVs from (-1, -1) to (1, 1) for circle math
    out.uv = positionOffset; 
    out.color = instance.color;
    out.glow = instance.glowIntensity;
    out.seed = instance.seed;
    out.rotation = instance.rotation;
    out.type = instance.type;
    out.radius = instance.radius;
    out.time = instance.time; // Pass simulation time or uniform time
    
    return out;
}

// MARK: - Fragment Shader
fragment float4 fragmentShader(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    // 1. Circle Cutout
    float dist = length(in.uv);
    if (in.type != 6 && dist > 1.0) discard_fragment();
    
    // 2. Rotate UVs for Texture (THIS MAKES IT SPIN)
    float c = cos(in.rotation);
    float s = sin(in.rotation);
    float2x2 rotMat = float2x2(c, -s, s, c);
    float2 rotatedUV = rotMat * in.uv;
    
    // 3. Lighting (Fake 3D Sphere)
    // Calculate normal of a sphere at this pixel
    float z = sqrt(max(0.0, 1.0 - dist * dist));
    float3 normal = float3(rotatedUV, z);
    
    // Light source from top-left
    float3 lightDir = normalize(float3(-0.3, 0.3, 1.0));
    float light = dot(normal, lightDir);
    light = smoothstep(-0.2, 1.0, light); // Soften shadows
    
    float3 finalColor = in.color.rgb;
    float alpha = 1.0;

    // 4. Procedural Textures based on Type
    if (in.type == 6) { // TRAIL
        float core = 1.0 - smoothstep(0.0, 0.2, dist);
        float glow = 1.0 - smoothstep(0.0, 1.0, dist);
        float noiseVal = fbm(in.uv * 2.0 - float2(0, in.time * 3.0));
        finalColor = in.color.rgb + float3(0.5, 0.5, 0.2) * core;
        finalColor += in.color.rgb * noiseVal * 0.5;
        alpha = glow * in.color.a * (0.5 + noiseVal * 0.5);
        light = 1.0;
    } else if (in.type == 5) { // BLACK HOLE
        // Accretion Disk (Bright Ring)
        float ring = smoothstep(0.5, 0.7, dist) * (1.0 - smoothstep(0.8, 1.0, dist));
        // Event Horizon (Black Center)
        float horizon = 1.0 - smoothstep(0.4, 0.45, dist);
        
        float3 diskColor = float3(0.6, 0.1, 0.8); // Deep Purple
        finalColor = mix(diskColor * 3.0, float3(0.0), horizon);
        alpha = ring + horizon; // Only draw ring and center
        light = 1.0; // Black holes don't have standard shading
        
    } else if (in.type == 4) { // STAR
        // Turbulent surface
        float n = fbm(rotatedUV * 3.0 + float2(in.time * 0.2, 0.0));
        finalColor += float3(1.0, 0.8, 0.4) * n;
        light = 1.2; // Self-emissive
        
    } else if (in.type == 3) { // GAS GIANT
        // Banded noise
        float bands = sin(rotatedUV.y * 10.0 + fbm(rotatedUV * 5.0) * 2.0);
        float3 bandColor = mix(in.color.rgb, in.color.rgb * 0.5, bands * 0.5 + 0.5);
        finalColor = bandColor;
        
    } else if (in.type == 2) { // LAVA
         float n = fbm(rotatedUV * 4.0 + in.seed);
         finalColor = mix(finalColor, float3(0.1, 0.0, 0.0), n); // Dark rocks
         // Glowing cracks
         float cracks = smoothstep(0.4, 0.5, noise(rotatedUV * 6.0 + in.time * 0.1));
         finalColor += float3(1.0, 0.5, 0.0) * cracks * 2.0;
         light = max(light, cracks); // Cracks glow in dark
        
    } else { // ROCK / ICE
        // Craters / Surface noise
        float n = fbm(rotatedUV * 4.0 + in.seed);
        finalColor = mix(finalColor, finalColor * 0.6, n);
        
        // Craters (simple dots)
        float craterNoise = noise(rotatedUV * 8.0 + in.seed * 5.0);
        if (craterNoise > 0.7) {
            finalColor *= 0.6; // Dark spots
        }
    }
    
    // 5. Apply Lighting & Glow
    float3 result = finalColor * light;
    
    // Rim lighting (Atmosphere)
    float rim = 1.0 - z;
    result += in.color.rgb * rim * in.glow * 0.5;
    
    // 6. Apply Big Bang Flash
    float flash = uniforms.flashIntensity;
    if (flash > 0.0 && flash < 0.8) {
        float prism = sin(in.uv.x * 10.0 + uniforms.time * 20.0) * 0.1;
        result += float3(prism, -prism, 0.0);
    }
    result = mix(result, float3(1.0, 1.0, 1.0), flash);

    return float4(result, alpha);
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

    float2 camPos = -float2(uniforms.viewMatrix[3].x, uniforms.viewMatrix[3].y);
    float parallaxFactor = (1.0 - star.depth * 0.8);
    float2 parallaxPos = star.position - (camPos * parallaxFactor);

    float wrapSize = 8000.0;
    float halfSize = 4000.0;
    float2 distFromCam = parallaxPos;

    if (distFromCam.x > halfSize) distFromCam.x -= wrapSize;
    if (distFromCam.x < -halfSize) distFromCam.x += wrapSize;
    if (distFromCam.y > halfSize) distFromCam.y -= wrapSize;
    if (distFromCam.y < -halfSize) distFromCam.y += wrapSize;

    float4 pos = uniforms.projectionMatrix * float4(distFromCam, 0.9, 1.0);
    out.position = pos;
    out.color = star.color;
    out.size = star.size;
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

// NEBULA SHADER (Fullscreen Quad)
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
    out.position = float4(quadVertices[vertexID], 1.0, 1.0);
    
    float2 camPos = -float2(uniforms.viewMatrix[3].x, uniforms.viewMatrix[3].y);
    float2 worldPos = (out.position.xy * 0.5 * uniforms.screenSize) + camPos * 0.3;
    out.uv = worldPos * 0.0005;
    return out;
}

fragment float4 nebulaFragment(NebulaOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]])
{
    float2 uv = in.uv;

    float n1 = fbm(uv + float2(uniforms.time * 0.01, 0));
    float3 col1 = float3(0.1, 0.0, 0.2);
    float3 col2 = float3(0.0, 0.1, 0.3);
    float3 nebula = mix(col1, col2, n1);

    float n2 = fbm(uv * 2.0 - float2(0, uniforms.time * 0.015));
    float bright = smoothstep(0.4, 0.8, n2);
    nebula += float3(0.4, 0.3, 0.1) * bright * 0.3;

    float3 space = float3(0.01, 0.01, 0.02);
    return float4(space + nebula * 0.5, 1.0);
}
