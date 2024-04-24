//
//  spline.metal
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/7.
//

#include "pch.h"

namespace spline {
    
void BSplineBasis::calc(float u, int i, float4 result[MAX_ORDER]) const {
    // R: result: [ N_{i,0} ]
    // R: result: [ N_{i-1, 1}, N_{i, 1} ]
    // R: ...
    // R: result: [ N_{i-p, p}, ..., N_{i, p} ]
    
    // G: result: [ N'_{i, 0} ]
    // G: result: [ N'_{i-1,1}, N'_{i,1} ]
    // G: ...
    // G: result: [ N'_{i-p,p}, ..., N'_{i,p} ]
    result[0] = float4(1, 0, 0, 0);
    for (int p = 1; p <= degree; p++) {
        int rightTrimCount = i + p - knotCount + 2;
        int leftTrimCount = p - i;
        
        int firstIndex = leftTrimCount > 0 ? leftTrimCount : 1;
        int lastIndex = rightTrimCount > 0 ? p - rightTrimCount : p - 1;
        
        int lastID = rightTrimCount > 0 ? i - rightTrimCount : i - 1;
        
        float3 left, right; // terms in basis
        
        if (rightTrimCount > 0) {
            result[p] = float4(0);
            right = result[lastIndex].rgb / (knots[lastID + p + 1] - knots[lastID + 1]);
        } else {
            right = left = result[p - 1].rgb / (knots[i + p] - knots[i]);
            float value = (u - knots[i]) * left.r;
            float3 derivative = p * left;
            result[p] = float4(value, derivative);
        }
        
        for (int j = lastIndex, id = lastID; j >= firstIndex; j--, id--) {
            // calculate result[j]
            left = result[j - 1].rgb / (knots[id + p] - knots[id]);
            float value = left.r * (u - knots[id]) + right.r * (knots[id + p + 1] - u);
            float3 derivative = p * (left - right);
            
            result[j] = float4(value, derivative);
            right = left;
        }
            
        if (leftTrimCount > 0) {
            result[leftTrimCount - 1] = float4(0);
        } else {
            float value = (knots[i + 1] - u) * right.r;
            float3 derivative = -p * right;
            result[0] = float4(value, derivative);
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
                                    uint gid [[thread_position_in_grid]]
                                    ) {
    const int order = args.degree + 1;
    const float domainLeft = knots[intervalId];
    const float domainRight = knots[intervalId + 1];
    
    const float intervalLength = domainRight - domainLeft;
    
    const uint width = result.get_width(0);
    const float u = fma(gid, intervalLength / (width - 1), domainLeft);
    
    float4 value[MAX_ORDER] { 0 };
    BSplineBasis N(knots, args.knotCount, args.degree);
    N.calc(u, intervalId, value);
    
    for (int i = 0; i < order; i++)
        result.write(value[i], gid, i);
}
    
[[kernel]] void basisAt(constant BSplineKernelArgument& args [[buffer(0)]],
                        constant float * knots [[buffer(1)]], // length = (degree + 1) * 2
                        constant int& intervalId [[buffer(2)]],
                        constant float& u [[buffer(3)]],
                        device float * result [[buffer(4)]]) {
    
    const int order = args.degree + 1;
    
    float4 value[MAX_ORDER] { 0 };
    BSplineBasis N(knots, args.knotCount, args.degree);
    N.calc(u, intervalId, value);
    
    for (int i = 0; i < order; i++)
        result[i] = value[i].r;
}

[[kernel]] void firstDerivativeAt(constant BSplineKernelArgument& args [[buffer(0)]],
                                  constant float * knots [[buffer(1)]], // length = (degree + 1) * 2
                                  constant int& intervalId [[buffer(2)]],
                                  constant float& u [[buffer(3)]],
                                  device float * result [[buffer(4)]]) {
    
    const int order = args.degree + 1;
    
    float4 value[MAX_ORDER] { 0 };
    BSplineBasis N(knots, args.knotCount, args.degree);
    N.calc(u, intervalId, value);
    
    for (int i = 0; i < order; i++)
        result[i] = value[i].g;
}

[[kernel]] void secondDerivativeAt(constant BSplineKernelArgument& args [[buffer(0)]],
                                   constant float * knots [[buffer(1)]], // length = (degree + 1) * 2
                                   constant int& intervalId [[buffer(2)]],
                                   constant float& u [[buffer(3)]],
                                   device float * result [[buffer(4)]]) {
    
    const int order = args.degree + 1;
    
    float4 value[MAX_ORDER] { 0 };
    BSplineBasis N(knots, args.knotCount, args.degree);
    N.calc(u, intervalId, value);
    
    for (int i = 0; i < order; i++)
        result[i] = value[i].b;
}

[[kernel]] void thirdDerivativeAt(constant BSplineKernelArgument& args [[buffer(0)]],
                                  constant float * knots [[buffer(1)]], // length = (degree + 1) * 2
                                  constant int& intervalId [[buffer(2)]],
                                  constant float& u [[buffer(3)]],
                                  device float * result [[buffer(4)]]) {
    
    const int order = args.degree + 1;
    
    float4 value[MAX_ORDER] { 0 };
    BSplineBasis N(knots, args.knotCount, args.degree);
    N.calc(u, intervalId, value);
    
    for (int i = 0; i < order; i++)
        result[i] = value[i].a;
}
    
    
[[host_name("curveFiller") kernel]] 
void fillInterpolationMatrix(constant BSplineKernelArgument& args [[buffer(0)]],
                             constant float * knots [[buffer(1)]], // length = (degree + 1) * 2
                             constant int& columnCount [[buffer(2)]],
                             device float* matrix [[buffer(3)]],
                             constant float * samples [[buffer(4)]], // \hat{u}
                             uint gid [[thread_position_in_grid]] // matrix[gid][...]
                             ) {
    const int order = args.degree + 1;
    const float sample = samples[gid];
    
    float4 value[MAX_ORDER] { 0 };
    BSplineBasis N(knots, args.knotCount, args.degree);
    int intervalId = 0;
    if (sample == knots[0]) {
        while (knots[intervalId + 1] <= sample) intervalId++;
    } else {
        while (knots[intervalId + 1] < sample) intervalId++;
    }
    N.calc(sample, intervalId, value);
    
    for (int i = 0; i < columnCount; i++) matrix[gid * columnCount + i] = 0;
    for (int i = 0; i < order; i++) {
        matrix[gid * columnCount + intervalId - args.degree + i] = value[i].r;
    }
}
    
[[host_name("surfaceFiller") kernel]] 
void fillInterpolationMatrix(constant BSplineKernelArgument& uArgs [[buffer(0)]],
                             constant BSplineKernelArgument& vArgs [[buffer(1)]],
                             constant float * uKnots [[buffer(2)]],
                             constant float * vKnots [[buffer(3)]],
                             constant int& columnCount [[buffer(4)]], // == vBasisCount * uBasisCount
                             device float* matrix [[buffer(5)]],
                             constant float * uSamples [[buffer(6)]],
                             constant float * vSamples [[buffer(7)]],
                             uint gid [[thread_position_in_grid]]
                             ) {
    const int uOrder = uArgs.degree + 1;
    const int vOrder = vArgs.degree + 1;
    const int uBasisCount = uArgs.knotCount - uOrder;
//    const int vBasisCount = vArgs.knotCount - vOrder;
    const float uSample = uSamples[gid];
    const float vSample = vSamples[gid];
    
    float4 uValue[MAX_ORDER] { 0 };
    float4 vValue[MAX_ORDER] { 0 };
    
    BSplineBasis N(uKnots, uArgs.knotCount, uArgs.degree);
    BSplineBasis M(vKnots, vArgs.knotCount, vArgs.degree);
    
    int uIntervalId = 0;
    if (uSample == uKnots[0]) {
        while (uKnots[uIntervalId + 1] <= uSample) uIntervalId++;
    } else {
        while (uKnots[uIntervalId + 1] < uSample) uIntervalId++;
    }
    
    int vIntervalId = 0;
    if (vSample == vKnots[0]) {
        while (vKnots[vIntervalId + 1] <= vSample) vIntervalId++;
    } else {
        while (vKnots[vIntervalId + 1] < vSample) vIntervalId++;
    }
    
    N.calc(uSample, uIntervalId, uValue);
    M.calc(vSample, vIntervalId, vValue);
    
    for (int k = 0; k < columnCount; k++) matrix[gid * columnCount + k] = 0;
    for (int i = 0; i < uOrder; i++) {
        for (int j = 0; j < vOrder; j++) {
            matrix[gid * columnCount + (uIntervalId - uArgs.degree + i) + uBasisCount * (vIntervalId - vArgs.degree + j)] = uValue[i].r * vValue[j].r;
        }
    }
}
    
[[host_name("uIsoCurveConstraintFiller") kernel]]
void fillUIsoCurveConstraintMatrix(constant BSplineKernelArgument& uArgs [[buffer(0)]],
                                   constant BSplineKernelArgument& vArgs [[buffer(1)]],
                                   constant float * vKnots [[buffer(2)]],
                                   constant int& columnCount [[buffer(3)]], // == vBasisCount * uBasisCount
                                   device float* matrix [[buffer(4)]],
                                   constant float * vSamples [[buffer(5)]],
                                   uint2 gid [[thread_position_in_grid]] // (isoline index, control point index)
                                   ) {
    const int uOrder = uArgs.degree + 1;
    const int vOrder = vArgs.degree + 1;
    const int uBasisCount = uArgs.knotCount - uOrder;
//    const int vBasisCount = vArgs.knotCount - vOrder;
    const int vSampleIndex = gid.x;
    const int uBasisIndex = gid.y;
    const float vSample = vSamples[vSampleIndex];
    
    float4 vValue[MAX_ORDER] { 0 };
    
    BSplineBasis N(vKnots, vArgs.knotCount, vArgs.degree);
    
    int vIntervalId = 0;
    if (vSample == vKnots[0]) {
        while (vKnots[vIntervalId + 1] <= vSample) vIntervalId++;
    } else {
        while (vKnots[vIntervalId + 1] < vSample) vIntervalId++;
    }
    
    N.calc(vSample, vIntervalId, vValue);
    
//    for (int k = 0; k < columnCount; k++) matrix[(vSampleIndex * (uBasisCount - 2) + uBasisIndex) * columnCount + k] = -1;
    for (int j = 0; j < vOrder; j++) {
        matrix[(vSampleIndex * (uBasisCount - 2) + uBasisIndex) * columnCount + (vIntervalId - vArgs.degree + j) * uBasisCount + uBasisIndex + 1] = vValue[j].r;
    }
}
    
[[host_name("vIsoCurveConstraintFiller") kernel]]
void fillVIsoCurveConstraintMatrix(constant BSplineKernelArgument& uArgs [[buffer(0)]],
                                   constant BSplineKernelArgument& vArgs [[buffer(1)]],
                                   constant float * uKnots [[buffer(2)]],
                                   constant int& columnCount [[buffer(3)]], // == vBasisCount * uBasisCount
                                   device float* matrix [[buffer(4)]],
                                   constant float * uSamples [[buffer(5)]],
                                   uint2 gid [[thread_position_in_grid]] // (isoline index, control point index)
                                   ) {
    const int uOrder = uArgs.degree + 1;
    const int vOrder = vArgs.degree + 1;
    const int uBasisCount = uArgs.knotCount - uOrder;
    const int vBasisCount = vArgs.knotCount - vOrder;
    const int uSampleIndex = gid.x;
    const int vBasisIndex = gid.y;
    const float uSample = uSamples[uSampleIndex];
    
    float4 uValue[MAX_ORDER] { 0 };
    
    BSplineBasis N(uKnots, uArgs.knotCount, uArgs.degree);
    
    int uIntervalId = 0;
    if (uSample == uKnots[0]) {
        while (uKnots[uIntervalId + 1] <= uSample) uIntervalId++;
    } else {
        while (uKnots[uIntervalId + 1] < uSample) uIntervalId++;
    }
    
    N.calc(uSample, uIntervalId, uValue);
    
//    for (int k = 0; k < columnCount; k++) matrix[(uSampleIndex * vBasisCount + vBasisIndex) * columnCount + k] = 0;
    for (int i = 0; i < uOrder; i++) {
        matrix[(uSampleIndex * (vBasisCount - 2) + vBasisIndex) * columnCount + (uIntervalId - uArgs.degree + i) + uBasisCount * (vBasisIndex + 1)] = uValue[i].r;
    }
}

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
    out.pointSize = 0.5 * actualSize / distance + actualSize / 4;
    
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
