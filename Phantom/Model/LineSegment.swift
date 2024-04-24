//
//  LineSegment.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/29.
//

import Metal

class LineSegment: DrawableBase {
    private(set) var start: SIMD3<Float>
    private(set) var end: SIMD3<Float>
    
    private var vertices: [Vertex]
    private lazy var vertexBuffer: MTLBuffer? = {
        system.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }()
    
    override func draw(_ encoder: MTLRenderCommandEncoder,
                       instanceCount: Int = 1,
                       baseInstance: Int = 0) {
        
        encoder.setRenderPipelineState(Axes.geometryPassState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertices.count, instanceCount: instanceCount, baseInstance: baseInstance)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertices.count, instanceCount: instanceCount, baseInstance: baseInstance)
    }
    
    init(start: SIMD3<Float>,
         end: SIMD3<Float>) {
        self.start = start
        self.end = end
        self.vertices = [Vertex(position: start, color: .one), Vertex(position: end, color: [0, 0, 0, 1])]
    }
}
