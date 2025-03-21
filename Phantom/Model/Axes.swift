//
//  Axes.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/20.
//

import Metal

@MainActor
class Axes {
    static private let vertices: [Vertex] = [
        Vertex(position: [0, 0, 0], color: [1, 0, 0, 1]),
        Vertex(position: [1, 0, 0], color: [1, 0, 0, 1]),

        Vertex(position: [0, 0, 0], color: [0, 1, 0, 1]),
        Vertex(position: [0, 1, 0], color: [0, 1, 0, 1]),

        Vertex(position: [0, 0, 0], color: [0, 0, 1, 1]),
        Vertex(position: [0, 0, 1], color: [0, 0, 1, 1])
    ]
    
    static private var vertexBuffer: MTLBuffer? = {
        MetalSystem.shared.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }()
    
    static var geometryPassState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.descriptor
        descriptor.vertexFunction = MetalSystem.shared.library.makeFunction(name: "geometry::vertexShader")
        descriptor.fragmentFunction = MetalSystem.shared.library.makeFunction(name: "geometry::lineFragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = MetalSystem.shared.hdrTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.label = "Geometry Pass Pipeline State for Lines"
        return try! MetalSystem.shared.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    static func draw(_ encoder: MTLRenderCommandEncoder,
                     instanceCount: Int = 1,
                     baseInstance: Int = 0
    ) {
        encoder.setRenderPipelineState(geometryPassState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertices.count, instanceCount: instanceCount, baseInstance: baseInstance)
    }
}
