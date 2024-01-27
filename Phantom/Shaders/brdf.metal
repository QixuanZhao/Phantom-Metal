//
//  brdf.metal
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/3.
//

#include "pch.h"

//float diffuse();
//float normalDistribution();
//float geometryFactor();
//float3 fresnel(float3 v, float3 h); // view and halfway vectors

//float diffuseLambert();
//float diffuseOrenNayar();

float brdf::normalDistributionGaussian(float3 n, float3 h, float roughness) {
    constexpr float ka = 1;
    const float cosineDelta = dot(n, h);
    const float delta = acos(cosineDelta);
    const float powerSqrt = delta / roughness;
    const float power = powerSqrt * powerSqrt;
    return ka * cosineDelta * exp(-power);
}

float brdf::normalDistributionBeckmann(float3 n, float3 h, float roughness) {
    constexpr float ka = 1;
    constexpr float pi = M_PI_F;
    const float cosineDelta = dot(n, h);
    const float square = cosineDelta * cosineDelta;
    const float m2 = roughness * roughness;
    const float m2square = m2 * square;
    const float factor = ka / (pi * m2square * square);
    const float power = (square - 1) / (m2square);
    return factor * exp(power);
}

float brdf::normalDistributionPhong(float3 n, float3 h, float roughness) {
    constexpr float ka = 1;
    constexpr float pi2 = M_PI_2_F;
    const float cosineDelta = dot(n, h);
    return ka * (roughness + 2) / pi2 * pow(cosineDelta, roughness);
}

float brdf::normalDistributionTrowbridgeReitzGGX(float3 n, float3 h, float3 t, float3 b, float2 roughness) {
    const float cosTheta = dot(n, h);
    
    float3 T = cross(n, float3(0, 0, 1));
    if (length_squared(T) == 0) T = cross(n, float3(0.1, 0.1, 1));
//    const float3 tangent = normalize(T);
//    const float3 bitangent = cross(n, tangent);
    const float3x3 mat = transpose(float3x3(t, b, n));
    const float3 localHalf = mat * h;
    const float2 uv = localHalf.xy / cosTheta;
    
    const float innerTerm = length_squared(float3(cosTheta, uv / roughness));
    const float denominator = M_PI_F * roughness.x * roughness.y * innerTerm * innerTerm;
    return 1 / denominator;
}

float brdf::normalDistributionWard(float3 n, float3 h, float2 roughness) {
    constexpr float ka = 1;
    constexpr float pi = M_PI_F;
    const float cosineDelta = dot(n, h);
    const float square = cosineDelta * cosineDelta;
    const float tangentDeltaSquared = (1 - square) / square;
    const float sineAltitude = h.z;
    const float cosineAltitude = sqrt(1 - sineAltitude * sineAltitude);
    const float2 azimuthTrignometry = h.xy / cosineAltitude;
    const float power = -tangentDeltaSquared * length_squared(azimuthTrignometry / roughness);
    const float denominator = pi * roughness.x * roughness.y;
    const float numerator = ka * exp(power);
    return numerator / denominator;
}

float brdf::geometryBeckmann(float3 v, float3 n, float3 h, float roughness) {
    const float vh = dot(v, h);
    const float vn = dot(v, n);
    const float determinant = vh / vn;
    if (determinant <= 0) return 0;
    
    constexpr float ka = 1;
    const float cosVSquared = vn * vn;
    const float tanV = sqrt(1 - cosVSquared) / vn;
    const float a = 1 / (roughness * tanV);
    const float a2 = a * a;
    float factor = 1;
    if (a < 1.6) factor = (3.535 * a + 2.181 * a2) / (1 + 2.276 * a + 2.577 * a2);
    return factor * ka;
}

float brdf::geometryPhong(float3 v, float3 n, float3 h, float roughness) {
    const float vh = dot(v, h);
    const float vn = dot(v, n);
    const float determinant = vh / vn;
    if (determinant <= 0) return 0;
    
    constexpr float ka = 1;
    const float cosVSquared = vn * vn;
    const float tanV = sqrt(1 - cosVSquared) / vn;
    const float a = sqrt(0.5 * roughness + 1) / tanV;
    const float a2 = a * a;
    const float factor = a < 1.6 ? ((3.535 * a + 2.181 * a2) / (1 + 2.276 * a + 2.577 * a2)) : 1;
    return factor * ka;
}

float brdf::geometryTrowbridgeReitzGGX(float3 v, float3 n, float3 h, float roughness) {
    const float vh = dot(v, h);
    const float vn = dot(v, n);
    const float determinant = vh * vn; // need sign of vh / vn
    if (determinant <= 0) return 0;
    
    const float m2 = roughness * roughness;
    const float cos2V = vn * vn;
    const float denominator = 1 + sqrt(1 - m2 + m2 / cos2V);
    return 2 / denominator;
}

float brdf::cheapGeometryKelemenSzirmayKalos(float3 l, float3 h) {
    const float dotProduct = dot(l, h);
    const float square = dotProduct * dotProduct;
    return 1 / square;
}


float3 brdf::fresnelPrecise(floatc3 indicesOfRefraction, float3 viewDirection, float3 halfway) {
//    array<float, 3> a;
    floatc3 squareIOR = indicesOfRefraction * indicesOfRefraction;
    float cosine = abs(dot(viewDirection, halfway));
    floatc3 g = (squareIOR + fma(cosine, cosine, -1)).sqrt();
    floatc3 gpc = g + cosine;
    floatc3 gmc = g - cosine;
    floatc3 ngpc = gpc * cosine - 1;
    floatc3 dgmc = gmc * cosine + 1;
    
    floatc3 frac1 = gmc / gpc;
    floatc3 frac2 = ngpc / dgmc;
    
    floatc3 f = (frac1 * frac1 * (frac2 * frac2 + 1)) / 2;
    float3 fresnelTerm = float3(f[0].length(), f[1].length(), f[2].length());
    return fresnelTerm;
}


float3 brdf::fresnelSchlick(float3 albedo, float3 viewDirection, float3 halfway) {
    float cosThetaH = dot(viewDirection, halfway);
    float oneMinusCosThetaH = 1.0 - cosThetaH;

    // Schlick's approximation
    float3 fresnelTerm = albedo + (1.0 - albedo) * pow(oneMinusCosThetaH, 5.0);

    return fresnelTerm;
}




float brdf::normalDistribution(float3 n, float3 h, float3 t, float3 b, float2 roughness) {
    return normalDistributionTrowbridgeReitzGGX(n, h, t, b, roughness);
}

float brdf::geometryFactor(float3 l, float3 v, float3 n, float3 h, float roughness) {
    return geometryTrowbridgeReitzGGX(v, n, h, roughness) * geometryTrowbridgeReitzGGX(l, n, h, roughness);
}

float2x3 brdf::specularReflectance(float3 normal, float3 tangent, float3 bitangent,
                   float3 light,
                   float3 halfway,
                   float3 view,
                   float2 roughness,
                   float3 indicesOfRefraction,
                   float3 absorptionCoefficients) {
    floatc3 ri(floatc(1));
    for (int i = 0; i < 3; i++) ri[i] = floatc(indicesOfRefraction[i], absorptionCoefficients[i]);
    float3 fresnelTerm = fresnelPrecise(ri, view, halfway);
    
    float normalTerm = normalDistribution(normal, halfway, tangent, bitangent, roughness);
    if (normalTerm <= 0) return float2x3(float3(0), fresnelTerm);
    
    float geometryTerm = geometryFactor(light, view, normal, halfway, roughness.x);
    
    const float nl = dot(normal, light);
    const float nv = dot(normal, view);
    const float denominator = 4 * nl * nv;
    const float3 specular = fresnelTerm * normalTerm * geometryTerm / denominator;
    return float2x3(specular, fresnelTerm);
}

float3 brdf::diffuseReflectance(float sigma, float3 lightDir, float3 viewDir, float3 normal, float3 albedo) {
    float cosThetai = dot(lightDir, normal);
    float cosThetav = dot(viewDir,  normal);
    
    float thetaI = acos(cosThetai);
    float thetaV = acos(cosThetav);
    float cosine = cos(thetaI - thetaV);
    
    float alpha = max(thetaI, thetaV);
    float beta = min(thetaI, thetaV);
    float mean = (alpha + beta) / 2;
    
    float sigmaSquared = sigma * sigma;
    float fracBeta = beta * 2 / M_PI_F;
    float fracBetaSquared = fracBeta * fracBeta;
    
    float factor23 = sigmaSquared / (sigmaSquared + 0.09);
    
    float C1 = fma(-0.5, sigmaSquared / (sigmaSquared + 0.33), 1);
    float C2 = cosine > 0 ? (0.45 * sin(alpha) * factor23) : (0.45 * (fma(-fracBetaSquared, fracBeta, sin(alpha))) * factor23);
    float C3 = 2 * 2 * 0.125 / (M_PI_F * M_PI_F) * factor23 * alpha * alpha * fracBetaSquared;
    
    float L1 = fma(C3, (1 - abs(cosine)) * tan(mean), fma(C2, cosine * tan(beta), C1));
    float3 L2 = albedo * 0.17 * sigmaSquared / (sigmaSquared + 0.13) * (fma(-cosine, fracBetaSquared, 1));
    
    return (L1 + L2) / M_PI_F;
}

