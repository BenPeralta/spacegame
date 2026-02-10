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
    if (in.type != 6 && in.type != 7 && dist > 1.0) discard_fragment();
    
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
        float noiseVal = fbm(in.uv * 2.0 - float2(0, in.time * 3.0));
        float core = 1.0 - smoothstep(0.0, 0.2, dist);
        finalColor = in.color.rgb + float3(0.5, 0.5, 0.2) * core;
        finalColor += in.color.rgb * noiseVal * 0.5;
        alpha = (1.0 - smoothstep(0.0, 1.0, dist)) * in.color.a;
        light = 1.0;
    } else if (in.type == 5) { // BLACK HOLE (1:17 Style)
        float pulse = sin(uniforms.time * 3.0) * 0.02;
        float horizonRadius = 0.40 + pulse;
        float horizon = 1.0 - smoothstep(horizonRadius - 0.01, horizonRadius + 0.01, dist);
        
        float photonRing = smoothstep(horizonRadius, horizonRadius + 0.02, dist) * (1.0 - smoothstep(horizonRadius + 0.05, horizonRadius + 0.08, dist));
        
        float angle = atan2(in.uv.y, in.uv.x);
        float spiral = angle * 3.0 + uniforms.time * 4.0;
        float diskNoise = fbm(float2(dist * 12.0 - uniforms.time * 2.0, spiral));
        float diskShape = smoothstep(0.45, 0.6, dist) * (1.0 - smoothstep(0.9, 1.0, dist));
        float doppler = smoothstep(-1.0, 1.0, -in.uv.x);
        float3 diskColor = mix(float3(0.4, 0.0, 0.8), float3(0.2, 0.6, 1.0), diskNoise * doppler);
        if (in.glow > 1.5) diskColor += float3(0.8, 0.4, 0.2) * (1.0 - dist);
        
        finalColor = diskColor * diskShape * (0.5 + 1.5 * diskNoise);
        finalColor += float3(1.0) * photonRing * 3.0;
        finalColor = mix(finalColor, float3(0.0), horizon);
        alpha = clamp(diskShape + horizon + photonRing, 0.0, 1.0);
        light = 1.0;
    } else if (in.type == 7) { // RELATIVISTIC JET
        float core = 1.0 - smoothstep(0.0, 0.3, fabs(in.uv.y));
        float noiseVal = fbm(in.uv * float2(1.0, 5.0) - float2(in.time * 10.0, 0.0));
        finalColor = float3(0.4, 0.9, 1.0) * core;
        finalColor += float3(0.8, 1.0, 1.0) * noiseVal * core;
        alpha = core * in.color.a;
        light = 1.0;
    } else if (in.type == 8) { // NEUTRON STAR (PULSAR)
        float core = 1.0 - smoothstep(0.0, 0.6, dist);
        finalColor = float3(0.8, 0.9, 1.0) * (1.0 + core * 2.0);
        
        float spinSpeed = in.time * 20.0;
        float2 spinUV = float2(
            in.uv.x * cos(spinSpeed) - in.uv.y * sin(spinSpeed),
            in.uv.x * sin(spinSpeed) + in.uv.y * cos(spinSpeed)
        );
        float field = fbm(spinUV * 5.0);
        finalColor += float3(0.0, 0.5, 1.0) * field * 0.5;
        
        float angle = atan2(in.uv.y, in.uv.x);
        float beam = sin(angle * 2.0 + spinSpeed);
        beam = smoothstep(0.9, 1.0, beam);
        float beamMask = smoothstep(0.3, 0.8, dist);
        finalColor += float3(0.5, 1.0, 1.0) * beam * beamMask * 2.0;
        
        light = 1.0;
    } else if (in.type == 9) { // DWARF STAR (Concentrated Power - Golden Mini Sun)
        // Core: Sharp, intense
        float core = 1.0 - smoothstep(0.0, 0.7, dist);
        float3 base = in.color.rgb; // Golden Yellow
        
        // Fast, energetic surface noise
        float n = fbm(rotatedUV * 6.0 - float2(in.time * 0.8, in.time * 0.4));
        float spots = smoothstep(0.3, 0.8, n);
        
        // Blindingly hot highlights
        float3 surface = mix(base, float3(1.0, 0.9, 0.8), spots * 0.8);
        
        // Corona / Rim
        float corona = smoothstep(0.8, 1.0, dist) * (1.0 - smoothstep(1.2, 1.5, dist));
        
        finalColor = surface + float3(1.0, 0.9, 0.3) * core * 1.5;
        finalColor += float3(1.0, 0.7, 0.1) * corona * 2.0;
        
        light = 2.0; // Very bright
    } else if (in.type == 4) { // STAR (Improved - White)
        float core = 1.0 - smoothstep(0.0, 0.9, dist);
        float3 base = in.color.rgb;
        float n = fbm(rotatedUV * 4.0 - float2(in.time * 0.1, in.time * 0.2));
        float spots = smoothstep(0.4, 0.7, n);
        float3 surface = mix(base, float3(0.9, 0.95, 1.0), spots * 0.5);
        finalColor = surface + float3(0.9, 0.95, 1.0) * core * 0.8;
        light = 1.5;
    } else if (in.type == 3) { // GAS GIANT (Animated Bands)
        float shift = in.time * 0.2;
        float2 warp = rotatedUV;
        warp.x += sin(rotatedUV.y * 10.0 + in.time) * 0.1;
        float bands = sin(warp.y * 12.0 + fbm(warp * 3.0 + shift) * 3.0);
        float stormDist = distance(rotatedUV, float2(0.3, 0.2));
        float storm = 1.0 - smoothstep(0.15, 0.2, stormDist);
        float3 baseColor = in.color.rgb;
        float3 stormColor = baseColor * 0.5 + float3(0.2, 0.0, 0.0);
        finalColor = mix(baseColor, baseColor * 0.6, bands * 0.5 + 0.5);
        finalColor = mix(finalColor, stormColor, storm);
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
    
    if (uniforms.lensingStrength > 0.0) {
        float2 toBH = parallaxPos - uniforms.blackHolePos;
        float distBH = length(toBH);
        distBH = max(distBH, 10.0);
        float distortion = uniforms.lensingStrength / (distBH * 0.8);
        distortion = min(distortion, 300.0);
        parallaxPos += normalize(toBH) * distortion;
    }

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
