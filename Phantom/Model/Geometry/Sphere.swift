//
//  Sphere.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/20.
//

import simd
import Metal

class Sphere: TransformableGeometry, StaticDrawable {
    static private var vertices: [Vertex] = []
    static private var indices:  [UInt16] = []
    
    static private var indexBuffer:  MTLBuffer?
    static private var vertexBuffer: MTLBuffer?
    
    static let latitudeLineCount = 11 // including polar points
    static let longitudeLineCount = 10
    
    static var typeReady = false
    
    static func initType(_ device: MTLDevice?) {
        if typeReady { return }
        let northPoleIndex = 0
        let southPoleIndex = latitudeLineCount - 1
        
        vertices.append(Vertex(position: SIMD3<Float>(0, 0, 1), normal: SIMD3<Float>(0, 0, 1), color: .one))
        for i in northPoleIndex+1..<southPoleIndex {
            let latitude = Float.pi / 2 - Float(i) / Float(latitudeLineCount) * Float.pi
            for j in 0..<longitudeLineCount {
                let longitude = 2 * Float(j) / Float(longitudeLineCount) * Float.pi
                let direction = SIMD3<Float>(
                    cos(latitude) * cos(longitude),
                    cos(latitude) * sin(longitude),
                    sin(latitude)
                )
                
                vertices.append(Vertex(position: direction, normal: direction, color: .one))
            }
        }
        vertices.append(Vertex(position: SIMD3<Float>(0, 0, -1), normal: SIMD3<Float>(0, 0, -1), color: .one))
        
        let northPoleVertexIndex = 0
        let southPoleVertexIndex = vertices.count - 1
        for j in 0..<longitudeLineCount {
            indices.append(UInt16(northPoleVertexIndex))
            indices.append(UInt16(northPoleVertexIndex + j + 1))
            indices.append(UInt16(northPoleVertexIndex + (j + 1) % longitudeLineCount + 1))
            
            indices.append(UInt16(southPoleVertexIndex))
            indices.append(UInt16(southPoleVertexIndex - (j + 1)))
            indices.append(UInt16(southPoleVertexIndex - (j + 1) % longitudeLineCount - 1))
        }
        
        var innerStartVertexIndex = 1
        
        while innerStartVertexIndex + longitudeLineCount < vertices.count - 1 {
            for k in 0..<longitudeLineCount {
                indices.append(UInt16(innerStartVertexIndex + k))
                indices.append(UInt16(innerStartVertexIndex + k + longitudeLineCount))
            }
            indices.append(UInt16(innerStartVertexIndex))
            indices.append(UInt16(innerStartVertexIndex + longitudeLineCount))
            
            innerStartVertexIndex = innerStartVertexIndex + longitudeLineCount
        }
        
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
        indexBuffer = device?.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count)
        
        typeReady = true
    }
    
    override required init(_ device: MTLDevice?) {
        super.init(device)
//        showAxes = true
    }
    
    func draw(_ encoder: MTLRenderCommandEncoder) {
        setModelBuffer(encoder)
        encoder.setVertexBuffer(Self.vertexBuffer, offset: 0, index: VertexBufferPosition.vertex.rawValue)
        
        guard let indexBuffer = Self.indexBuffer else { return }
        
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: Self.longitudeLineCount * 6, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        for k in 1..<Self.latitudeLineCount-2 {
            encoder.drawIndexedPrimitives(type: .triangleStrip,
                                          indexCount: (Self.longitudeLineCount + 1) * 2,
                                          indexType: .uint16,
                                          indexBuffer: indexBuffer,
                                          indexBufferOffset: Self.longitudeLineCount * 6 * MemoryLayout<UInt16>.stride + (Self.longitudeLineCount + 1) * 2 * (k - 1) * MemoryLayout<UInt16>.stride)
        }
        
    }
    
    func draw(_ encoder: MTLRenderCommandEncoder, _ instanceCount: Int) {
        encoder.setVertexBuffer(Self.vertexBuffer, offset: 0, index: VertexBufferPosition.vertex.rawValue)
        
        guard let indexBuffer = Self.indexBuffer else { return }
        
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: Self.longitudeLineCount * 6, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0,
            instanceCount: instanceCount)
        for k in 1..<Self.latitudeLineCount-2 {
            encoder.drawIndexedPrimitives(type: .triangleStrip,
                                          indexCount: (Self.longitudeLineCount + 1) * 2,
                                          indexType: .uint16,
                                          indexBuffer: indexBuffer,
                                          indexBufferOffset: Self.longitudeLineCount * 6 * MemoryLayout<UInt16>.stride + (Self.longitudeLineCount + 1) * 2 * (k - 1) * MemoryLayout<UInt16>.stride,
                                          instanceCount: instanceCount)
        }
        
    }
}

