//
//  bernstein.metal
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

#include "pch.h"

namespace bernstein {
    
[[kernel]] void computeBernsteinBasis(texture1d_array<float, access::write> result [[texture(0)]],
                                      uint gid [[thread_position_in_grid]]
                                      ) {
    const int degree = result.get_array_size() - 1;
    const uint width = result.get_width();
    const float u = gid * 1.0f / (width - 1);
    
    for (int i = 0; i <= degree; i++) {
        float num = 1;
        float den = 1;
        
        for (int j = degree; j > degree - i; j--) num *= j;
        for (int j = 2; j <= i; j++) den *= j;
        
        float ui = 1;
        float uim1 = 0;
        float cunmi = 1;
        float cunmi1 = 0;
        
        float cu = 1 - u;
        for (int j = 0; j < i; j++) {
            uim1 = ui;
            ui *= u;
        }
        
        for (int j = 0; j < degree - i; j++) {
            cunmi1 = cunmi;
            cunmi *= cu;
        }
        
        float basis = ui * cunmi * num / den;
        float derivative = (i * uim1 * cunmi - (degree - i) * ui * cunmi1) * num / den;
        result.write(float4(basis, derivative, 0, 0), gid, i);
    }
}
    
[[vertex]] RasterizerData bézeirCurveShader(Vertex data [[stage_in]], // buffer 0
                                            constant Uniform& uniform [[buffer(1)]],
                                            constant float4x4 * models [[buffer(2)]],
                                            constant Vertex* controlPoints [[buffer(3)]],
                                            texture1d_array<float> basis [[texture(0)]],
                                            uint instanceID [[instance_id]],
                                            uint vertexID   [[vertex_id]]) {
    RasterizerData out;
    
    float3 point(0);
    const int order = basis.get_array_size();
    float4 color(0);
    for (int i = 0; i < order; i++) {
        const float B = basis.sample(n, data.parameter.x, i).r;
        color += B * controlPoints[i].color;
        point += B * controlPoints[i].position;
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
    
}
