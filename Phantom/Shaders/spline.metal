//
//  spline.metal
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/7.
//

#include "pch.h"

namespace spline {
    
void BSplineBasis::calc(float u, int i, float2 result[MAX_ORDER]) const {
    // R: result: [ N_{i,0} ]
    // R: result: [ N_{i-1, 1}, N_{i, 1} ]
    // R: ...
    // R: result: [ N_{i-p, p}, ..., N_{i, p} ]
    
    // G: result: [ N'_{i, 0} ]
    // G: result: [ N'_{i-1,1}, N'_{i,1} ]
    // G: ...
    // G: result: [ N'_{i-p,p}, ..., N'_{i,p} ]
    result[0] = float2(1, 0);
    for (int p = 1; p <= degree; p++) {
        int rightTrimCount = i + p - knotCount + 2;
        int leftTrimCount = p - i;
        
        int firstIndex = leftTrimCount > 0 ? leftTrimCount : 1;
        int lastIndex = rightTrimCount > 0 ? p - rightTrimCount : p - 1;
        
//        int firstID = leftTrimCount > 0 ? i - p + leftTrimCount : i - p + 1;
        int lastID = rightTrimCount > 0 ? i - rightTrimCount : i - 1;
        
        float left, right; // terms in basis
        
        if (rightTrimCount > 0) {
            result[p] = float2(0);
            right = result[lastIndex].r / (knots[lastID + p + 1] - knots[lastID + 1]);
        } else {
            right = left = result[p - 1].r / (knots[i + p] - knots[i]);
            float value = (u - knots[i]) * left;
            float derivative = p * left;
            result[p] = float2(value, derivative);
        }
        
        for (int j = lastIndex, id = lastID; j >= firstIndex; j--, id--) {
            // calculate result[j]
            left = result[j - 1].r / (knots[id + p] - knots[id]);
            float value = left * (u - knots[id]) + right * (knots[id + p + 1] - u);
            float derivative = p * (left - right);
            result[j] = float2(value, derivative);
            right = left;
        }
            
        if (leftTrimCount > 0) {
            result[leftTrimCount - 1] = float2(0);
        } else {
            float value = (knots[i + 1] - u) * right;
            float derivative = -p * right;
            result[0] = float2(value, derivative);
        }
    }
}
    
struct BSplineKernelArgument {
    int degree;
    int knotCount;
};

[[kernel]] void computeBSplineBasis(texture1d_array<float, access::write> result [[texture(0)]],
                                    constant BSplineKernelArgument& args [[buffer(0)]],
                                    constant float * knots [[buffer(1)]], // length = (degree + 1) * 2
                                    constant int& intervalId [[buffer(2)]],
                                    uint2 gid [[thread_position_in_grid]]
                                    ) {
    const int order = args.degree + 1;
//    const float domainLeft = knots[args.degree];
//    const float domainRight = knots[order];
    
    const float domainLeft = knots[intervalId];
    const float domainRight = knots[intervalId + 1];
    
    const float intervalLength = domainRight - domainLeft;
    
    const uint width = result.get_width(0);
    const float u = fma(gid.x, intervalLength / (width - 1), domainLeft);
    
    float2 value[MAX_ORDER] { 0 };
    BSplineBasis N(knots, args.knotCount, args.degree);
//    BSplineBasis N(knots, order + order, args.degree);
    N.calc(u, intervalId, value);
    
    for (int i = 0; i < order; i++)
        result.write(float4(value[i], 0), gid.x, i);
}
    
/**
 * the vertex shader
 */

struct KnotSpan {
    int startControlPointIndex [[id(0)]];
    texture1d_array<float> basis [[id(1)]]; // array size is the order of the basis
};

[[vertex]] RasterizerData curveShader(Vertex data [[stage_in]], // buffer 0
                                       constant Uniform& uniform [[buffer(1)]],
                                       constant float4x4 * models [[buffer(2)]],
                                       constant Vertex* controlPoints [[buffer(3)]],
                                       constant int& startCPIndex [[buffer(4)]],
                                       texture1d_array<float> basis [[texture(0)]],
                                       uint instanceID [[instance_id]],
                                       uint vertexID   [[vertex_id]]) {
    RasterizerData out;
    
    float3 point(0);
    const int order = basis.get_array_size();
    float4 color(0);
    for (int i = 0; i < order; i++) {
        const float N = basis.sample(n, data.parameter.x, i).r;
        color += N * controlPoints[startCPIndex + i].color;
        point += N * controlPoints[startCPIndex + i].position;
    }
    
    float4 globalPosition = models[instanceID] * float4(point, 1.0);
    float4 globalNormal = float4(0);
    
    float4 viewPosition = uniform.view * globalPosition;
    float  distance = length(viewPosition.xyz);
    
    out.position = uniform.projection * viewPosition;
    
    out.color          = color;
    out.globalPosition = globalPosition.xyz;
    out.globalNormal   = globalNormal.xyz;
    
    const float actualSize = uniform.pointSizeAndCurvilinearPerspective.x;
    out.pointSize = 0.5 * actualSize / distance;
    
    return out;
}
    
[[patch(quad, 4), vertex]]
RasterizerData surfaceShader(patch_control_point<Vertex> patchControlVertices [[stage_in]],
                             constant Uniform& uniform [[buffer(1)]],
                             constant float4x4* models [[buffer(2)]],
                             constant Vertex* controlPoints [[buffer(3)]],
                             constant int32_t* controlPointIndex [[buffer(4)]], // start u, start v, total u, total v
                             texture1d_array<float> uBasis [[texture(0)]],
                             texture1d_array<float> vBasis [[texture(1)]],
                             uint instanceID [[instance_id]],
                             float2 parameters [[position_in_patch]]) {
    RasterizerData out;
    
    float3 point(0);
    float3 partialU(0);
    float3 partialV(0);
    float4 color = mix(float4(parameters, 0, 1), float4(1), 0.2);
    
    const int uOrder = uBasis.get_array_size();
    const int vOrder = vBasis.get_array_size();
    
    for (int i = 0; i < uOrder; i++) {
        const float2 Nu = uBasis.sample(n, parameters.x, i).rg;
        for (int j = 0; j < vOrder; j++) {
            const float2 Nv = vBasis.sample(n, parameters.y, j).rg;
            const int cpIndex = (controlPointIndex[0] + i) + (controlPointIndex[1] + j) * controlPointIndex[2];
            point += Nu.r * Nv.r * controlPoints[cpIndex].position;
            partialU += Nu.g * Nv.r * controlPoints[cpIndex].position;
            partialV += Nu.r * Nv.g * controlPoints[cpIndex].position;
//            color += Nu * Nv * controlPoints[cpIndex].color;
        }
    }
    
    float4 globalPosition  = models[instanceID] * float4(point, 1.0);
    float4 globalTangent   = models[instanceID] * float4(partialU, 0);
    float4 globalBitangent = models[instanceID] * float4(partialV, 0);
//    float4 globalNormal = models[instanceID] * float4(cross(partialU, partialV), 0);
    
    float4 viewPosition = uniform.view * globalPosition;
    float  distance = length(viewPosition.xyz);
    
    out.position = uniform.projection * viewPosition;
    
    out.color           = color;
    out.globalPosition  = globalPosition.xyz;
//    out.globalNormal    = globalNormal.xyz;
    
    out.globalTangent   = globalTangent.xyz;
    out.globalBitangent = globalBitangent.xyz;
    out.anistropic      = true;
    
    const float actualSize = uniform.pointSizeAndCurvilinearPerspective.x;
    out.pointSize = 0.5 * actualSize / distance;
    return out;
}
}
