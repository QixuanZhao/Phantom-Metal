//
//  PointSet.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/5.
//

import Metal

class PointSet: DrawableBase {
    private(set) var points: [SIMD3<Float>]
    
    private var vertices: [Vertex]
    private lazy var vertexBuffer: MTLBuffer? = {
        system.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }()
    
    override func draw(_ encoder: MTLRenderCommandEncoder,
                       instanceCount: Int = 1,
                       baseInstance: Int = 0) {
        
        encoder.setRenderPipelineState(Axes.geometryPassState)
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
