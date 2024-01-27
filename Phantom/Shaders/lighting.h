//
//  lighting.h
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/22.
//

#ifndef lighting_h
#define lighting_h

namespace analytical {
float3 parallelLight (float3 normal, float3 tangent, float3 bitangent,
                      float3 position,
                      float3 cameraPosition,
                      float diffuseBlend,
                      float3 albedo,
                      float3 refractive,
                      float3 extinction,
                      float2 roughness,
                      constant Light& light);
}

namespace brdf {
float3 diffuseReflectance(float roughness, float3 lightDir, float3 viewDir, float3 normal, float3 albedo);
float2x3 specularReflectance(float3 normal, float3 tangent, float3 bitangent,
                             float3 light, float3 halfway, float3 view, float2 roughness, float3 indicesOfRefraction, float3 absorptionCoefficients);

float normalDistribution(float3 n, float3 h, float3 t, float3 b, float2 roughness); // isotropical materials ignore roughness.y
float geometryFactor(float3 l, float3 v, float3 n, float3 h, float roughness);

//float diffuseLambert();
//float diffuseOrenNayar();

float normalDistributionGaussian(float3 n, float3 h, float roughness);
float normalDistributionBeckmann(float3 n, float3 h, float roughness);
float normalDistributionPhong(float3 n, float3 h, float roughness);
float normalDistributionTrowbridgeReitzGGX(float3 n, float3 h, float3 t, float3 b, float2 roughness);
float normalDistributionWard(float3 n, float3 h, float2 roughness);

float geometryBeckmann(float3 v, float3 n, float3 h, float roughness);
float geometryPhong(float3 v, float3 n, float3 h, float roughness);
float geometryTrowbridgeReitzGGX(float3 v, float3 n, float3 h, float roughness);
float cheapGeometryKelemenSzirmayKalos(float3 l, float3 h);

float3 fresnelPrecise(floatc3 indicesOfRefraction, float3 v, float3 h);
float3 fresnelSchlick(float3 albedo, float3 v, float3 h); // albedo = F(0)
}

#endif /* lighting_h */
