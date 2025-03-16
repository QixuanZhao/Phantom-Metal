//
//  Quad.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/1.
//

import Metal

@MainActor
class Quad {
    static var tessellatedGeometryState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.patchControlPointDescriptor
        descriptor.vertexFunction = MetalSystem.shared.library.makeFunction(name: "tessellation::quadShader")
        descriptor.fragmentFunction = MetalSystem.shared.library.makeFunction(name: "geometry::fragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = MetalSystem.shared.hdrTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.maxTessellationFactor = 64
        descriptor.isTessellationFactorScaleEnabled = false
        descriptor.tessellationControlPointIndexType = .none
        descriptor.tessellationFactorFormat = .half
        descriptor.tessellationPartitionMode = .pow2
        descriptor.tessellationFactorStepFunction = .constant
        descriptor.tessellationOutputWindingOrder = .counterClockwise
        descriptor.label = "Geometry Pass Pipeline State for Tessellated Quads"
        return try! MetalSystem.shared.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    static var tessellationFactorBuffer: MTLBuffer = {
        let buffer = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<MTLQuadTessellationFactorsHalf>.size)!
        buffer.label = "Tessellation Factor Buffer"
        
        Tessellator.fillFactors(
            buffer: buffer,
            edgeFactors: [10, 10, 10, 10],
            insideFactors: [10, 10]
        )
        
        return buffer
    }()
    
    static let vertices: [Vertex] = [
        Vertex(position: [-1, -1, 0], normal: [0, 0, 1], parameter: [0, 1], color: .one), // bottom left
        Vertex(position: [ 1, -1, 0], normal: [0, 0, 1], parameter: [1, 1], color: .one), // bottom right
        Vertex(position: [-1,  1, 0], normal: [0, 0, 1], parameter: [0, 0], color: .one), // top left
        Vertex(position: [ 1,  1, 0], normal: [0, 0, 1], parameter: [1, 0], color: .one), // top right
    ]
    
    static private(set) var vertexBuffer: MTLBuffer = {
        let buffer = MetalSystem.shared.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)!
        buffer.label = "Quad Vertex Buffer"
        return buffer
    }()
    
    static func draw(_ encoder: MTLRenderCommandEncoder,
                     instanceCount: Int = 1,
                     baseInstance: Int = 0
    ) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count, instanceCount: instanceCount, baseInstance: baseInstance)
    }
    
    static func drawTessellated(_ encoder: MTLRenderCommandEncoder,
                                instanceCount: Int = 1,
                                baseInstance: Int = 0) {
        
        encoder.setRenderPipelineState(tessellatedGeometryState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        encoder.setTessellationFactorBuffer(tessellationFactorBuffer, offset: 0, instanceStride: 0)
        
        encoder.drawPatches(numberOfPatchControlPoints: 4, patchStart: 0, patchCount: 1,
                            patchIndexBuffer: nil, patchIndexBufferOffset: 0,
                            instanceCount: instanceCount, baseInstance: baseInstance)
    }
}
