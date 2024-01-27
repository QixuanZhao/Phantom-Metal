//
//  tessellation.metal
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/16.
//

#include "pch.h"

namespace tessellation {
    [[kernel]] void computeTessellationFactors(device MTLQuadTessellationFactorsHalf * factors [[buffer(0)]],
                                               constant float4& edgeFactors [[buffer(1)]],
                                               constant float2& insideFactors [[buffer(2)]],
                                               uint patchIndex [[thread_position_in_grid]]) {
        device MTLQuadTessellationFactorsHalf & patchFactors = factors[patchIndex];
        patchFactors.edgeTessellationFactor[0] = edgeFactors.x; // left
        patchFactors.edgeTessellationFactor[1] = edgeFactors.y; // bottom
        patchFactors.edgeTessellationFactor[2] = edgeFactors.z; // right
        patchFactors.edgeTessellationFactor[3] = edgeFactors.w; // top
        patchFactors.insideTessellationFactor[0] = insideFactors.x; // horizontal
        patchFactors.insideTessellationFactor[1] = insideFactors.y; // vertical
    }
    
    [[patch(quad, 4), vertex]] 
    RasterizerData quadShader(patch_control_point<Vertex> controlVertices [[stage_in]],
                              float2 parameters [[position_in_patch]],
                              constant Uniform& uniform [[buffer(1)]],
                              constant float4x4* models [[buffer(2)]],
                              uint instanceID [[instance_id]]) {
        RasterizerData out;
        float3 p00 = controlVertices[0].position;
        float3 p01 = controlVertices[1].position;
        float3 p10 = controlVertices[2].position;
        float3 p11 = controlVertices[3].position;
        
        float3 pos = mix(mix(p00, p01, parameters.x), mix(p10, p11, parameters.x), parameters.y);
        
        float4 globalPosition = models[instanceID] * float4(pos, 1);
        float4 globalNormal = float4(0, 0, 1, 0);
        
        float4 viewPosition = uniform.view * globalPosition;
        float  distance = length(viewPosition.xyz);
        
        out.position = uniform.projection * viewPosition;
        
        out.color          = float4(1);
        out.globalPosition = globalPosition.xyz;
        out.globalNormal   = globalNormal.xyz;
        
        const float actualSize = uniform.pointSizeAndCurvilinearPerspective.x;
        out.pointSize = 0.5 * actualSize / distance;
        
        return out;
    }
}

