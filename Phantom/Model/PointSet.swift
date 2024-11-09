//
//  PointSet.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/5.
//

import Metal

class PointSet: DrawableBase {
    private(set) var points: [SIMD3<Float>]
    
    var color: SIMD4<Float> {
        vertices.first!.color
    }
    
    private var vertices: [Vertex]
    private lazy var vertexBuffer: MTLBuffer? = {
        system.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }()
    
    static var geometryPassState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.descriptor
        descriptor.vertexFunction = system.library.makeFunction(name: "geometry::vertexShader")
        descriptor.fragmentFunction = system.library.makeFunction(name: "geometry::pointFragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = system.hdrTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.label = "Geometry Pass Pipeline State for Points"
        return try! system.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    func setColor(_ color: SIMD4<Float>) {
        for i in 0..<vertices.count {
            vertices[i].color = color
        }
        vertexBuffer = system.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }
    
    override func draw(_ encoder: MTLRenderCommandEncoder,
                       instanceCount: Int = 1,
                       baseInstance: Int = 0) {
        
        encoder.setRenderPipelineState(Self.geometryPassState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertices.count, instanceCount: instanceCount, baseInstance: baseInstance)
    }
    
    init(points: [SIMD3<Float>]) {
        self.points = points
        self.vertices = points.map {
            Vertex(position: $0, color: [0, 0, 0, 1])
        }
    }
}
//20,776.90625
//3,500
//1,720.033447

//100
