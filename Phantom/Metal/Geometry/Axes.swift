//
//  Axes.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/19.
//

import simd
import Metal

struct Axes: Drawable {
    private var modelBuffer: MTLBuffer?
    var model: simd_float4x4 {
        simd_float4x4(diagonal: .one)
    }
    
    static private var vertexBuffer: MTLBuffer?
    static private let vertices: [Vertex] = [
        Vertex(position: vector3(0, 0, 0), color: vector4(1, 0, 0, 1)),
        Vertex(position: vector3(10, 0, 0), color: vector4(1, 0, 0, 1)),

        Vertex(position: vector3(0, 0, 0), color: vector4(0, 1, 0, 1)),
        Vertex(position: vector3(0, 10, 0), color: vector4(0, 1, 0, 1)),

        Vertex(position: vector3(0, 0, 0), color: vector4(0, 0, 1, 1)),
        Vertex(position: vector3(0, 0, 10), color: vector4(0, 0, 1, 1))
    ]
    
    func draw(_ encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(Self.vertexBuffer, offset: 0, index: iVertex)
        encoder.setVertexBuffer(modelBuffer, offset: 0, index: iModel)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 6)
    }
    
    static func initType(_ device: MTLDevice?) {
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }
    
    init(_ device: MTLDevice?) {
        modelBuffer = device?.makeBuffer(length: MemoryLayout.size(ofValue: model))
        modelBuffer?.contents().storeBytes(of: model, toByteOffset: 0, as: simd_float4x4.self)
    }
}
