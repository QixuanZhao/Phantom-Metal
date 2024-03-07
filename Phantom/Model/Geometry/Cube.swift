//
//  Cube.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/20.
//

import simd
import Metal

class Cube: TransformableGeometry, StaticDrawable {
    static private let vertices: [Vertex] = [
        Vertex(position: vector3( 0.5, -0.5, -0.5), normal: vector3(0, 0, -1), parameter: vector2(1, 0), color: vector4(1, 0, 0, 1)),
        Vertex(position: vector3(-0.5, -0.5, -0.5), normal: vector3(0, 0, -1), parameter: vector2(0, 0), color: vector4(1, 0, 0, 1)),
        Vertex(position: vector3( 0.5,  0.5, -0.5), normal: vector3(0, 0, -1), parameter: vector2(1, 1), color: vector4(1, 0, 0, 1)),
        Vertex(position: vector3(-0.5,  0.5, -0.5), normal: vector3(0, 0, -1), parameter: vector2(0, 1), color: vector4(1, 0, 0, 1)),
        
        Vertex(position: vector3( 0.5, -0.5, 0.5), normal: vector3(0, 0, 1), parameter: vector2(1, 0), color: vector4(0, 1, 0, 1)),
        Vertex(position: vector3(-0.5, -0.5, 0.5), normal: vector3(0, 0, 1), parameter: vector2(0, 0), color: vector4(0, 1, 0, 1)),
        Vertex(position: vector3( 0.5,  0.5, 0.5), normal: vector3(0, 0, 1), parameter: vector2(1, 1), color: vector4(0, 1, 0, 1)),
        Vertex(position: vector3(-0.5,  0.5, 0.5), normal: vector3(0, 0, 1), parameter: vector2(0, 1), color: vector4(0, 1, 0, 1)),
        
        Vertex(position: vector3( 0.5, -0.5, -0.5), normal: vector3(0, -1, 0), parameter: vector2(1, 0), color: vector4(0, 0, 1, 1)),
        Vertex(position: vector3(-0.5, -0.5, -0.5), normal: vector3(0, -1, 0), parameter: vector2(0, 0), color: vector4(0, 0, 1, 1)),
        Vertex(position: vector3( 0.5, -0.5,  0.5), normal: vector3(0, -1, 0), parameter: vector2(1, 1), color: vector4(0, 0, 1, 1)),
        Vertex(position: vector3(-0.5, -0.5,  0.5), normal: vector3(0, -1, 0), parameter: vector2(0, 1), color: vector4(0, 0, 1, 1)),
        
        Vertex(position: vector3( 0.5, 0.5, -0.5), normal: vector3(0, 1, 0), parameter: vector2(1, 0), color: vector4(1, 1, 0, 1)),
        Vertex(position: vector3(-0.5, 0.5, -0.5), normal: vector3(0, 1, 0), parameter: vector2(0, 0), color: vector4(1, 1, 0, 1)),
        Vertex(position: vector3( 0.5, 0.5,  0.5), normal: vector3(0, 1, 0), parameter: vector2(1, 1), color: vector4(1, 1, 0, 1)),
        Vertex(position: vector3(-0.5, 0.5,  0.5), normal: vector3(0, 1, 0), parameter: vector2(0, 1), color: vector4(1, 1, 0, 1)),
        
        Vertex(position: vector3(-0.5,  0.5, -0.5), normal: vector3(-1, 0, 0), parameter: vector2(1, 0), color: vector4(1, 0, 1, 1)),
        Vertex(position: vector3(-0.5, -0.5, -0.5), normal: vector3(-1, 0, 0), parameter: vector2(0, 0), color: vector4(1, 0, 1, 1)),
        Vertex(position: vector3(-0.5,  0.5,  0.5), normal: vector3(-1, 0, 0), parameter: vector2(1, 1), color: vector4(1, 0, 1, 1)),
        Vertex(position: vector3(-0.5, -0.5,  0.5), normal: vector3(-1, 0, 0), parameter: vector2(0, 1), color: vector4(1, 0, 1, 1)),
        
        Vertex(position: vector3(0.5,  0.5, -0.5), normal: vector3(1, 0, 0), parameter: vector2(1, 0), color: vector4(0, 1, 1, 1)),
        Vertex(position: vector3(0.5, -0.5, -0.5), normal: vector3(1, 0, 0), parameter: vector2(0, 0), color: vector4(0, 1, 1, 1)),
        Vertex(position: vector3(0.5,  0.5,  0.5), normal: vector3(1, 0, 0), parameter: vector2(1, 1), color: vector4(0, 1, 1, 1)),
        Vertex(position: vector3(0.5, -0.5,  0.5), normal: vector3(1, 0, 0), parameter: vector2(0, 1), color: vector4(0, 1, 1, 1)),
    ]
    
    static private let indices: [UInt16] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
    
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
        for i in 0..<6 {
            encoder.drawIndexedPrimitives(
                type: .triangleStrip,
                indexCount: 4,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: i * 4 * MemoryLayout<UInt16>.size
            )
        }
    }
}
