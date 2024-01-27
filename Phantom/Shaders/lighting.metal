//
//  blinn-phong.metal
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/22.
//

#include "pch.h"

float3 analytical::parallelLight (float3 normal, float3 tangent, float3 bitangent,
                                  float3 position,
                                  float3 cameraPosition,
                                  float diffuseBlend,
                                  float3 albedo,
                                  float3 refractive,
                                  float3 extinction,
                                  float2 roughness,
                                  constant Light& light) {
    if (length_squared(normal) == 0) return float3(1); // ignore vectors
    
    const float3 lightDirection = normalize(light.direction);
    const float3 viewDirection  = normalize(cameraPosition - position);
    const float3 halfwayVector  = normalize(lightDirection + viewDirection);
    
    const float cosine = max(dot(lightDirection, normal), 0.0);
    
    const float2x3 specularFresnel = brdf::specularReflectance(normal, tangent, bitangent,
                                                      lightDirection,
                                                      halfwayVector,
                                                      viewDirection,
                                                      roughness,
                                                      refractive,
                                                      extinction);
    const float3 specular = specularFresnel[0];
    const float3 fresnel = specularFresnel[1];
    const float3 diffuse = brdf::diffuseReflectance(sqrt(roughness.x * roughness.y), lightDirection, viewDirection, normal, albedo);
    // fused multiply-add: fma(a, b, c) = a * b + c
    return fma((1 - fresnel) * diffuseBlend / (extinction + 1), diffuse, specular) * cosine * light.intensity;
}
