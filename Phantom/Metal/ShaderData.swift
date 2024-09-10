//
//  Vertex.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/17.
//

import simd
import Metal
import ModelIO

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
    
    static var descriptor: MTLVertexDescriptor = {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].offset = MemoryLayout<Vertex>.offset(of: \.position)!
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].bufferIndex = BufferPosition.vertex.rawValue
        descriptor.attributes[1].offset = MemoryLayout<Vertex>.offset(of: \.normal)!
        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].bufferIndex = BufferPosition.vertex.rawValue
        descriptor.attributes[2].offset = MemoryLayout<Vertex>.offset(of: \.parameter)!
        descriptor.attributes[2].format = .float2
        descriptor.attributes[2].bufferIndex = BufferPosition.vertex.rawValue
        descriptor.attributes[3].offset = MemoryLayout<Vertex>.offset(of: \.color)!
        descriptor.attributes[3].format = .float4
        descriptor.attributes[3].bufferIndex = BufferPosition.vertex.rawValue
        
        descriptor.layouts[BufferPosition.vertex.rawValue].stride = MemoryLayout<Vertex>.stride
        descriptor.layouts[BufferPosition.vertex.rawValue].stepRate = 1
        descriptor.layouts[BufferPosition.vertex.rawValue].stepFunction = .perVertex
        return descriptor
    }()
    
    static var patchControlPointDescriptor: MTLVertexDescriptor = {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].offset = MemoryLayout<Vertex>.offset(of: \.position)!
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].bufferIndex = BufferPosition.vertex.rawValue
        descriptor.attributes[1].offset = MemoryLayout<Vertex>.offset(of: \.normal)!
        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].bufferIndex = BufferPosition.vertex.rawValue
        descriptor.attributes[2].offset = MemoryLayout<Vertex>.offset(of: \.parameter)!
        descriptor.attributes[2].format = .float2
        descriptor.attributes[2].bufferIndex = BufferPosition.vertex.rawValue
        descriptor.attributes[3].offset = MemoryLayout<Vertex>.offset(of: \.color)!
        descriptor.attributes[3].format = .float4
        descriptor.attributes[3].bufferIndex = BufferPosition.vertex.rawValue
        
        descriptor.layouts[BufferPosition.vertex.rawValue].stride = MemoryLayout<Vertex>.stride
        descriptor.layouts[BufferPosition.vertex.rawValue].stepRate = 1
        descriptor.layouts[BufferPosition.vertex.rawValue].stepFunction = .perPatchControlPoint
        return descriptor
    }()
    
    static var modelDescriptor: MDLVertexDescriptor {
        let descriptor = MDLVertexDescriptor()
        let position = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                         format: .float3,
                                         offset: MemoryLayout<Vertex>.offset(of: \.position)!,
                                         bufferIndex: BufferPosition.vertex.rawValue)
        let normal = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                       format: .float3,
                                       offset: MemoryLayout<Vertex>.offset(of: \.normal)!,
                                       bufferIndex: BufferPosition.vertex.rawValue)
        let parameter = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                           format: .float2,
                                           offset: MemoryLayout<Vertex>.offset(of: \.parameter)!,
                                           bufferIndex: BufferPosition.vertex.rawValue)
        let color = MDLVertexAttribute(name: MDLVertexAttributeColor,
                                       format: .float4,
                                       offset: MemoryLayout<Vertex>.offset(of: \.color)!,
                                       bufferIndex: BufferPosition.vertex.rawValue)
        color.initializationValue = .one
        normal.initializationValue = .zero
        parameter.initializationValue = .zero
        descriptor.attributes[0] = position
        descriptor.attributes[1] = normal
        descriptor.attributes[2] = parameter
        descriptor.attributes[3] = color
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Vertex>.stride)
        return descriptor
    }
}

struct Uniform {
    var view: simd_float4x4
    var projection: simd_float4x4
    var cameraPositionAndFOV: SIMD4<Float>
    var planesAndframeSize: SIMD4<Float>
    var pointSizeAndCurvilinearPerspective: SIMD4<Float> // for alignment's sake
//    var curvilinearPerspective: Bool
}

struct Light {
    var intensity: Float
    var roughness: Float
    var ambient  : Float
    var direction: SIMD3<Float> = .one
}

struct Material {
    var albedoSpecular: SIMD4<Float>;
    var refractiveIndicesRoughnessU: SIMD4<Float>;
    var extinctionCoefficentsRoughnessV: SIMD4<Float>;
};

enum BufferPosition: Int {
    case vertex = 0, uniform, model, light, material
}

enum ColorAttachment: Int {
    case color = 0, 
         position,
         normal,
         albedoSpecular,
         refractiveRoughness1,
         extinctionRoughness2
}
