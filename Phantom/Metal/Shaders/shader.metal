//
//  vertex-shader.metal
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/12.
//

#include <metal_stdlib>
using namespace metal;

struct Uniform {
    float4x4 view;
    float4x4 projection;
    float3 cameraPosition;
};

struct Vertex {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float4 color    [[attribute(2)]];
};

struct RasterizerData {
    float4 position [[position]];
    float4 color;
    
    float4 globalPosition;
    float4 globalNormal;
};

[[vertex]] RasterizerData vertexShader(Vertex data [[stage_in]],
                                       constant Uniform& uniform [[buffer(1)]],
                                       constant float4x4& model [[buffer(2)]]) {
    RasterizerData out;
    
    float4 globalPosition = model * float4(data.position, 1.0);
    float4 globalNormal = model * float4(data.normal, 0.0);
    
    out.position = uniform.projection * (uniform.view * globalPosition);
    out.color    = data.color;
    
    out.globalPosition = globalPosition;
    out.globalNormal = globalNormal;
    
    return out;
}

float4 calculateParallelLight (RasterizerData data, float3 cameraPosition);

[[fragment]] float4 fragmentShader(RasterizerData in [[stage_in]], 
                                   constant Uniform& uniform [[buffer(1)]]) {
    return calculateParallelLight(in, uniform.cameraPosition) + in.color * 0.5;
}

float4 calculateParallelLight (RasterizerData data, float3 cameraPosition) {
    if (length(data.globalNormal) == 0) return data.color;
    float3 normal = normalize(data.globalNormal.xyz);
    const float3 lightDirection = -normalize(float3(1, 1, 1));
    const float3 viewDirection  = normalize(cameraPosition - data.globalPosition.xyz);
    
    const float cosine = dot(normal, viewDirection);
    if (cosine < 0) {
        normal = -normal;
    }
    
    const float3 halfwayVector  = normalize(-lightDirection + viewDirection);
    const float cosineSpecular = dot(halfwayVector, normal);
    
    const float3 lightOut = reflect(lightDirection, normal);
    const float cosineDiffuse = dot(lightOut, viewDirection);
    
    const float3 specular = cosineSpecular * 1 * data.color.rgb;
    const float3 diffuse = cosineDiffuse > 0 ? (cosineDiffuse * 1 * data.color.rgb) : float3(0);
    return float4(specular + diffuse, 1);
}
