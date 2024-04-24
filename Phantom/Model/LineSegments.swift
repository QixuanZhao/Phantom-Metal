//
//  LineSegments.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/29.
//

import Metal

class LineSegments: DrawableBase {
    private(set) var segments: [(SIMD3<Float>, SIMD3<Float>)]
    
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
    
    init(segments: [(SIMD3<Float>, SIMD3<Float>)]) {
        self.segments = segments
        self.vertices = segments.flatMap { [$0.0, $0.1] }.map { Vertex(position: $0, color: [0, 0, 0, 1]) }
    }
}
