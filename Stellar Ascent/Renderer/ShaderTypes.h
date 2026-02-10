#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Visual Types for the Shader
enum EntityVisualType {
    VisualTypeRock = 0,
    VisualTypeIce = 1,
    VisualTypeLava = 2,
    VisualTypeGas = 3,
    VisualTypeStar = 4,
    VisualTypeBlackHole = 5,
    VisualTypeTrail = 6,
    VisualTypeJet = 7,
    VisualTypeNeutron = 8
};

struct InstanceData {
    vector_float2 position;
    vector_float2 velocity;
    float radius;
    vector_float4 color;
    float glowIntensity;
    float seed;            // Random seed for procedural generation
    vector_float4 crackColor;
    float crackIntensity;
    
    // NEW: Drifter Star Visuals
    float rotation;        // Current rotation angle in radians
    int type;             // VisualType enum
    float time;           // For animated textures (clouds/lava)
};

struct Uniforms {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    float time;
    vector_float2 screenSize;
    float flashIntensity;
    
    vector_float2 blackHolePos;
    float lensingStrength;
};

#endif /* ShaderTypes_h */
