//
//  Square.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/19.
//

import simd
import Metal

class Square: TransformableGeometry, StaticDrawable {
    static private let vertices: [Vertex] = [
        Vertex(position: vector3( 0.5, -0.5, 0), normal: vector3(0, 0, 1), color: vector4(1, 1, 1, 1)),
        Vertex(position: vector3(-0.5, -0.5, 0), normal: vector3(0, 0, 1), color: vector4(1, 1, 1, 1)),
        Vertex(position: vector3( 0.5,  0.5, 0), normal: vector3(0, 0, 1), color: vector4(1, 1, 1, 1)),
        Vertex(position: vector3(-0.5,  0.5, 0), normal: vector3(0, 0, 1), color: vector4(1, 1, 1, 1))
    ]
    
    static private let indices: [UInt16] = [0, 1, 2, 3]
    
    static private var indexBuffer: MTLBuffer?
    static private var vertexBuffer: MTLBuffer?
    
    static func initType(_ device: MTLDevice?) {
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
        indexBuffer = device?.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count)
    }
    
    override required init(_ device: MTLDevice?) {
        super.init(device)
        showAxes = true
    }
    
    func draw(_ encoder: MTLRenderCommandEncoder) {
        setModelBuffer(encoder)
        encoder.setVertexBuffer(Self.vertexBuffer, offset: 0, index: VertexBufferPosition.vertex.rawValue)
        
        guard let indexBuffer = Self.indexBuffer else { return }
        encoder.drawIndexedPrimitives(
            type: .triangleStrip, 
            indexCount: Self.indices.count,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: .zero
        )
    }
}
