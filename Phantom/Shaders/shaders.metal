//
//  vertex-shader.metal
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/12.
//

#include "pch.h"

namespace geometry {
    /**
     * the vertex shader
     */
    [[vertex]] RasterizerData vertexShader(Vertex data [[stage_in]],
                                           constant Uniform& uniform [[buffer(1)]],
                                           constant float4x4* models [[buffer(2)]],
                                           uint instanceID [[instance_id]],
                                           uint vertexID   [[vertex_id]]) {
        RasterizerData out;
        
        float4 globalPosition = models[instanceID] * float4(data.position, 1.0);
        float4 globalNormal = models[instanceID] * float4(data.normal, 0.0);
        
        float4 viewPosition = uniform.view * globalPosition;
        float  distance = length(viewPosition.xyz);
        
        out.position = uniform.projection * viewPosition;
        
        out.color          = data.color;
        out.globalPosition = globalPosition.xyz;
        out.globalNormal   = globalNormal.xyz;
        
        const float actualSize = uniform.pointSizeAndCurvilinearPerspective.x;
        out.pointSize = actualSize / distance;
        
        return out;
    }
    
    /**
     * the fragment shader
     */
    [[early_fragment_tests, fragment]] GeometryData fragmentShader(RasterizerData in [[stage_in]],
                                                                   constant Material& material [[buffer(4)]]) {
        GeometryData out;
        out.albedoSpecular = material.albedoSpecular;
        out.refractiveIndices_roughnessU = material.refractiveIndicesRoughnessU;
        out.extinctionCoefficents_roughnessV = material.extinctionCoefficentsRoughnessV;
        if (in.anistropic) {
            float3 tangent = normalize(in.globalTangent);
            float3 bitangent = normalize(in.globalBitangent);
            float tangentAltitude = asin(tangent.z);
            float tangentAzimuth  = atan2(tangent.y / cos(tangentAltitude), tangent.x / cos(tangentAltitude));
            float bitangentAltitude = asin(bitangent.z);
            float bitangentAzimuth  = atan2(bitangent.y / cos(bitangentAltitude), bitangent.x / cos(bitangentAltitude));
            out.normal = float4(tangentAzimuth, tangentAltitude, bitangentAzimuth, bitangentAltitude);
            out.position_normalFormat = float4(in.globalPosition, 4); // set w = 4 to use (tT, pT, tB, pB) normal format
        } else {
            out.normal = length_squared(in.globalNormal) > 0 ? float4(normalize(in.globalNormal), 0) : float4(0);
            out.position_normalFormat = float4(in.globalPosition, 1); // set w = 1 to use (x, y, z) normal format
        }
        return out;
    }
    
//    /**
//     * the patch fragment shader
//     */
//    [[early_fragment_tests, fragment]] GeometryData patchFragmentShader(RasterizerData in [[stage_in]]) {
//        GeometryData out;
//        out.albedoSpecular = in.color;
//        out.normal = length_squared(in.globalNormal) > 0 ? float4(normalize(in.globalNormal), 0) : float4(0);
//        out.position_normalFormat = float4(in.globalPosition, 1); // set w = 1 to use (x, y, z) normal format
//        return out;
//    }
    
    /**
     * the line fragment shader (can be used to draw axes, curves, etc.)
     */
    [[early_fragment_tests, fragment]] GeometryData lineFragmentShader(RasterizerData in [[stage_in]]) {
        GeometryData out;
        out.albedoSpecular = in.color;
        out.normal = float4(0);
        out.position_normalFormat = float4(in.globalPosition, 0); // set w = 0 to disable normal
        return out;
    }
}

namespace postprocess {
    /**
     * the vertex shader that processes a screen quad
     */
    [[vertex]] QuadData vertexShader(Vertex data [[stage_in]],
                                     uint instanceID [[instance_id]]) {
        QuadData out;
        out.position = float4(data.position, 1.0);
        out.parameter = data.parameter;
        return out;
    }
    
    [[fragment]] ColorData fragmentShader(QuadData in [[stage_in]],
                                          texture2d<float> frame    [[texture(0)]],
                                          constant Uniform& uniform [[buffer(1)]]) {
        ColorData out;
        float2 parameter = in.position.xy;
        
        if (uniform.pointSizeAndCurvilinearPerspective.y > 0) {
            parameter /= uniform.planesAndframeSize.zw;
            parameter = fma(parameter, 2, -1);
            float theta = uniform.cameraPositionAndFOV.w / 2;
            float tanT = tan(theta);
            float tanP = tanT * uniform.planesAndframeSize.z / uniform.planesAndframeSize.w;

            float R2 = uniform.pointSizeAndCurvilinearPerspective.y == 1 ? length_squared(1 / float2(cos(atan(tanP)), cos(theta))) : 1;
            
            parameter /= sqrt(R2 - length_squared(parameter * float2(tanP, tanT)));
            parameter = fma(uniform.planesAndframeSize.zw, parameter, uniform.planesAndframeSize.zw) / 2;
        }
        
        float4 color = frame.sample(p, parameter);
        out.color = color;
        return out;
    }
}

namespace deferred {
    /**
     * the fragment shader for deferred rendering pass
     */
    [[host_name("memorylessFS") fragment]]
    ColorData fragmentShader(QuadData in [[stage_in]],
                             float4 position_normalFormat           [[color(1), raster_order_group(0)]],
                             float4 normal                          [[color(2), raster_order_group(0)]],
                             float4 albedoSpecular                  [[color(3), raster_order_group(0)]],
                             float4 refractiveIndicesRoughnessU     [[color(4), raster_order_group(0)]],
                             float4 extinctionCoefficentsRoughnessV [[color(5), raster_order_group(0)]],
                             constant Uniform& uniform [[buffer(1)]],
                             constant Light&  light    [[buffer(3)]]) {
        ColorData out;
        
        float4 surfaceColor   = albedoSpecular;
        float3 globalPosition = position_normalFormat.xyz;
        float3 globalNormal   = float3(0);
        float3 tangent        = float3(0);
        float3 bitangent      = float3(0);
        
        // normal format:
        // 0 for normal absence
        // 1 for normalized (x, y, z)
        // 2 for (x, y), assuming x^2 + y^2 + z^2 = 1 and z >= 0
        // 3 for (theta, phi) of normal
        // 4 for (thetaT, phiT) of tangent, (thetaB, phiB) of bitangent
        if (position_normalFormat.w == 1) {
            globalNormal = normal.xyz;
        } else if (position_normalFormat.w == 2) {
            globalNormal = float3(normal.xy, sqrt(1 - length_squared(normal.xy)));
        } else if (position_normalFormat.w == 3) {
            globalNormal = float3(cos(normal.y) * cos(normal.x), cos(normal.y) * sin(normal.x), sin(normal.y));
        } else if (position_normalFormat.w == 4) {
            tangent = float3(cos(normal.y) * cos(normal.x), cos(normal.y) * sin(normal.x), sin(normal.y));
            bitangent = float3(cos(normal.w) * cos(normal.z), cos(normal.w) * sin(normal.z), sin(normal.w));
            globalNormal = cross(tangent, bitangent);
        }
        
        if (position_normalFormat.w != 4 && position_normalFormat.w != 0) {
            tangent = cross(globalNormal.xyz, float3(0,0,1));
            tangent = length_squared(tangent) == 0 ? normalize(cross(globalNormal.xyz, float3(0,0.1,1))) : normalize(tangent);
            bitangent = cross(globalNormal.xyz, tangent);
        }
        
        if (position_normalFormat.w != 0) {
            float3 illumination = analytical::parallelLight(globalNormal.xyz, tangent, bitangent,
                                                            globalPosition.xyz,
                                                            uniform.cameraPositionAndFOV.xyz,
                                                            (1 - albedoSpecular.w),
                                                            albedoSpecular.rgb,
                                                            refractiveIndicesRoughnessU.xyz,
                                                            extinctionCoefficentsRoughnessV.xyz,
                                                            float2(refractiveIndicesRoughnessU.w, extinctionCoefficentsRoughnessV.w),
                                                            light);
            illumination += light.ambient;
            surfaceColor.xyz *= illumination;
        }
        
        out.color = surfaceColor;
        
        return out;
    }
}
