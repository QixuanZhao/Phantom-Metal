//
//  Square.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/19.
//

import simd
import Metal

class Square: Transformation, Drawable {
    static private let vertices: [Vertex] = [
        Vertex(position: vector3( 0.5, -0.5, 0), normal: vector3(0, 0, 1), color: vector4(1, 1, 1, 1)),
        Vertex(position: vector3(-0.5, -0.5, 0), normal: vector3(0, 0, 1), color: vector4(1, 1, 1, 1)),
        Vertex(position: vector3( 0.5,  0.5, 0), normal: vector3(0, 0, 1), color: vector4(1, 1, 1, 1)),
        Vertex(position: vector3(-0.5,  0.5, 0), normal: vector3(0, 0, 1), color: vector4(1, 1, 1, 1))
    ]
    
    static private let indices: [UInt16] = [
        0, 1, 2, 3
    ]
    
    static private var indexBuffer: MTLBuffer?
    static private var vertexBuffer: MTLBuffer?
    
    static func initType(_ device: MTLDevice?) {
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
        indexBuffer = device?.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count)
    }
    
    private var uniformBuffer: MTLBuffer?
    
    required init(_ device: MTLDevice?) {
        super.init()
        uniformBuffer = device?.makeBuffer(length: MemoryLayout.size(ofValue: model))
    }
    
    func draw(_ encoder: MTLRenderCommandEncoder) {
        updateModel()
        
        uniformBuffer?.contents().storeBytes(of: model, as: simd_float4x4.self)
        encoder.setVertexBuffer(Self.vertexBuffer, offset: 0, index: iVertex)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: iModel)
        
        guard let indexBuffer = Self.indexBuffer else { return }
        encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: 4, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: .zero)
//        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}
