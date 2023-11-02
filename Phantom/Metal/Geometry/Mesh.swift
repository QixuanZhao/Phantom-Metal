//
//  Mesh.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/20.
//

import simd
import Metal

class Mesh: Transformation {
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    
    init(_ device: MTLDevice?, _ vertices: [Vertex]) {
        super.init()
        uniformBuffer = device?.makeBuffer(length: MemoryLayout.size(ofValue: model))
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }
    
    func draw(_ encoder: MTLRenderCommandEncoder) {
        updateModel()
        
        uniformBuffer?.contents().storeBytes(of: model, as: simd_float4x4.self)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: iVertex)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: iModel)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 3)
    }
}

