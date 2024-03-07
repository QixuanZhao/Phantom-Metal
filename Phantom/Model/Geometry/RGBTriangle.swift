//
//  RGBTriangle.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/19.
//

import simd
import Metal

class RGBTriangle: TransformableGeometry, StaticDrawable {
    static private let vertices: [Vertex] = [
        Vertex(position: vector3( 0.7, -0.7, 0), normal: vector3(0, 0, 1), color: vector4(1, 0, 0, 1)),
        Vertex(position: vector3(-0.7, -0.7, 0), normal: vector3(0, 0, 1), color: vector4(0, 1, 0, 1)),
        Vertex(position: vector3(   0,  0.7, 0), normal: vector3(0, 0, 1), color: vector4(0, 0, 1, 1)),
    ]
    
    static private var vertexBuffer: MTLBuffer?
    static func initType(_ device: MTLDevice?) {
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }
    
    override required init(_ device: MTLDevice?) { super.init(device) }
    
    func draw(_ encoder: MTLRenderCommandEncoder) {
        setModelBuffer(encoder)
        encoder.setVertexBuffer(Self.vertexBuffer, offset: 0, index: VertexBufferPosition.vertex.rawValue)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Self.vertices.count)
    }
}

