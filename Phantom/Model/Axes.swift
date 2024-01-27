//
//  Axes.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/20.
//

import simd
import Metal

class Axes {
    static private let vertices: [Vertex] = [
        Vertex(position: vector3(0, 0, 0), color: vector4(1, 0, 0, 1)),
        Vertex(position: vector3(1, 0, 0), color: vector4(1, 0, 0, 1)),

        Vertex(position: vector3(0, 0, 0), color: vector4(0, 1, 0, 1)),
        Vertex(position: vector3(0, 1, 0), color: vector4(0, 1, 0, 1)),

        Vertex(position: vector3(0, 0, 0), color: vector4(0, 0, 1, 1)),
        Vertex(position: vector3(0, 0, 1), color: vector4(0, 0, 1, 1))
    ]
    
    static private var vertexBuffer: MTLBuffer?
    static func initType(_ device: MTLDevice?) {
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }
    
    func draw(_ encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(Self.vertexBuffer, offset: 0, index: VertexBufferPosition.vertex.rawValue)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: Self.vertices.count)
    }
}
