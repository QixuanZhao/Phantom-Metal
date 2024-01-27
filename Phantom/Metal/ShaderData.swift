//
//  Vertex.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/17.
//

import simd
import Metal

struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var parameter: SIMD2<Float>
    var color: SIMD4<Float>
    
    init(position: SIMD3<Float>, normal: SIMD3<Float> = .zero, parameter: SIMD2<Float> = .zero, color: SIMD4<Float>) {
        self.position = position
        self.normal = normal
        self.parameter = parameter
        self.color = color
    }
    
    static var descriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].offset = MemoryLayout<Vertex>.offset(of: \.position)!
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].bufferIndex = VertexBufferPosition.vertex.rawValue
        descriptor.attributes[1].offset = MemoryLayout<Vertex>.offset(of: \.normal)!
        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].bufferIndex = VertexBufferPosition.vertex.rawValue
        descriptor.attributes[2].offset = MemoryLayout<Vertex>.offset(of: \.parameter)!
        descriptor.attributes[2].format = .float2
        descriptor.attributes[2].bufferIndex = VertexBufferPosition.vertex.rawValue
        descriptor.attributes[3].offset = MemoryLayout<Vertex>.offset(of: \.color)!
        descriptor.attributes[3].format = .float4
        descriptor.attributes[3].bufferIndex = VertexBufferPosition.vertex.rawValue
        
        descriptor.layouts[VertexBufferPosition.vertex.rawValue].stride = MemoryLayout<Vertex>.stride
        descriptor.layouts[VertexBufferPosition.vertex.rawValue].stepRate = 1
        descriptor.layouts[VertexBufferPosition.vertex.rawValue].stepFunction = .perVertex
        return descriptor
    }
}

struct Uniform {
    var view: simd_float4x4
    var projection: simd_float4x4
    var cameraPosition: SIMD3<Float>
    var pointSize: SIMD3<Float> // for alignment's sake, only x is used
}

struct BlinnPhongLight {
    var intensity: Float
    var shininess: Float
    var ambient  : Float
}

enum VertexBufferPosition: Int {
    case vertex = 0, uniform, model
}

enum FragmentBufferPosition: Int {
    case vertex = 0, uniform, model, light
}
