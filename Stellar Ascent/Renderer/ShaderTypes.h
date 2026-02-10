#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match Metal API buffer set calls.
typedef enum VertexInputIndex
{
    VertexInputIndexVertices     = 0,
    VertexInputIndexUniforms     = 1,
    VertexInputIndexViewport     = 2,
    VertexInputIndexInstances    = 3
} VertexInputIndex;

// Attribute index values shared between shader and C code to ensure Metal shader vertex attribute indices match the Metal API vertex descriptor.
typedef enum VertexAttribute
{
    VertexAttributePosition  = 0,
    VertexAttributeColor     = 1,
} VertexAttribute;

// Common vertex structure
typedef struct
{
    vector_float2 position;
    vector_float4 color;
    float size; // Point size for point primitives or radius for circle SDF
} Vertex;

// Per-instance data for our entities (rocks, player, etc)
typedef struct
{
    vector_float2 position;
    vector_float2 velocity;
    float radius;
    vector_float4 color;
    float glowIntensity;
    float seed;
    vector_float4 crackColor;      // Path-specific crack glow color
    float crackIntensity;          // 0.0–1.0 strength (increases with tier)
} InstanceData;

// Global uniforms
typedef struct
{
    vector_float2 cameraPosition;
    float zoomLevel;
    float time;
    vector_float2 viewportSize;
} Uniforms;

#endif /* ShaderTypes_h */
