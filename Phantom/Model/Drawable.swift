//
//  Geometry.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/23.
//

import MetalKit
import ModelIO

protocol Drawable {
    func draw(_ encoder: MTLRenderCommandEncoder, instanceCount: Int, baseInstance: Int) -> Void
}

class DrawableBase: Drawable, Equatable {
    static func == (lhs: DrawableBase, rhs: DrawableBase) -> Bool { lhs.name == rhs.name }
    
    var name: String = ""
    func draw(_ encoder: MTLRenderCommandEncoder, instanceCount: Int, baseInstance: Int) { }

//    var boundingBox: AxisAlignedBoundingBox = .init(diagonalVertices: (.zero, .zero))
//    func updateBoundingBox() {  }
}

class Mesh: DrawableBase {
    static var geometryPassState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.descriptor
        descriptor.vertexFunction = system.library.makeFunction(name: "geometry::vertexShader")
        descriptor.fragmentFunction = system.library.makeFunction(name: "geometry::fragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = system.hdrTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = system.geometryTextureDescriptor.pixelFormat
        descriptor.label = "Geometry Pass Pipeline State"
        return try! system.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    let mesh: MDLMesh
    let metalKitMesh: MTKMesh
    
    init(mesh: MDLMesh) throws {
        self.mesh = mesh
        self.metalKitMesh = try MTKMesh (mesh: mesh, device: system.device)
        super.init()
        super.name = mesh.name
    }
    
    override func draw(_ encoder: MTLRenderCommandEncoder, instanceCount: Int, baseInstance: Int) {
        if let meshBuffer = metalKitMesh.vertexBuffers.first {
            encoder.setRenderPipelineState(Self.geometryPassState)
            encoder.setVertexBuffer(meshBuffer.buffer, offset: meshBuffer.offset, index: BufferPosition.vertex.rawValue)
            for submesh in metalKitMesh.submeshes {
                encoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: submesh.indexCount,
                                              indexType: submesh.indexType,
                                              indexBuffer: submesh.indexBuffer.buffer, 
                                              indexBufferOffset: submesh.indexBuffer.offset,
                                              instanceCount: instanceCount,
                                              baseVertex: 0,
                                              baseInstance: baseInstance)
            }
            
        }
    }
}

class Geometry: DrawableBase {
    let vertices: [Vertex]
    let indices:  [UInt32]?
    var primitiveType: MTLPrimitiveType = .triangle
    
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer:  MTLBuffer?
    
    required init(name: String = "Geometry",
                  _ vertices: [Vertex],
                  _ indices: [UInt32]?
    ) {
        self.vertices = vertices
        self.vertexBuffer = system.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
        
        self.indices = indices
        if let indices {
            self.indexBuffer = system.device.makeBuffer(bytes: indices, length: MemoryLayout<UInt32>.stride * indices.count)
        }
        super.init()
        super.name = name
    }
    
    convenience init(name: String = "Geometry",
                     _ vertices: [Vertex],
                     _ indices:  [UInt32]?,
                     _ primitiveType: MTLPrimitiveType
    ) {
        self.init(name: name, vertices, indices)
        self.primitiveType = primitiveType
    }
    
    override func draw(_ encoder: MTLRenderCommandEncoder,
              instanceCount: Int = 1,
              baseInstance: Int = 0
    ) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        if let indices {
            encoder.drawIndexedPrimitives(type: primitiveType, indexCount: indices.count, indexType: .uint32, indexBuffer: indexBuffer!, indexBufferOffset: 0, instanceCount: instanceCount, baseVertex: 0, baseInstance: baseInstance)
        } else {
            encoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: vertices.count, instanceCount: instanceCount, baseInstance: baseInstance)
        }
    }
}
