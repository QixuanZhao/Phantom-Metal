//
//  data-types.h
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/22.
//

#ifndef data_types_h
#define data_types_h
struct Uniform {
    float4x4 view;
    float4x4 projection;
    float4   cameraPositionAndFOV;
    float4   planesAndFrameSize;
    float4   pointSizeAndCurvilinearPerspective;
};

struct Light {
    float intensity;
    float roughness;
    float ambient;
    float3 direction;
};

struct Material {
    float4 albedoSpecular;
    float4 refractiveIndicesRoughnessU;
    float4 extinctionCoefficentsRoughnessV;
};

struct Vertex {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 parameter [[attribute(2)]];
    float4 color     [[attribute(3)]];
};

struct RasterizerData {
    float4 position [[position]];
    float4 color;
    
    float3 globalPosition;
    float3 globalNormal;
    
    bool anistropic = false;
    float3 globalTangent = float3(0);
    float3 globalBitangent = float3(0);
    
    float pointSize [[point_size]];
    bool pointBorder = false;
};

struct QuadData {
    float4 position [[position]];
    float2 parameter;
};

struct ColorData {
    float4 color [[color(0), raster_order_group(1)]];
};

struct GeometryData {
    // normal format:
    // 0 for normal absence
    // 1 for normalized (x, y, z)
    // 2 for (x, y), assuming x^2 + y^2 + z^2 = 1 and z >= 0
    // 3 for (theta, phi) of normal
    // 4 for (thetaT, phiT) of tangent, (thetaB, phiB) of bitangent
    float4 position_normalFormat            [[color(1), raster_order_group(0)]];
    float4 normal                           [[color(2), raster_order_group(0)]];
    float4 albedoSpecular                   [[color(3), raster_order_group(0)]];
    float4 refractiveIndices_roughnessU     [[color(4), raster_order_group(0)]];
    float4 extinctionCoefficents_roughnessV [[color(5), raster_order_group(0)]];
};

#endif /* data_types_h */
