//
//  LineSegments.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/29.
//

import SwiftUI
import Metal
import simd

class LineSegments: DrawableBase {
    private(set) var segments: [(SIMD3<Float>, SIMD3<Float>)]
    
    private(set) var lengths: [Float]
    private(set) var maxLength: Float
    private(set) var minLength: Float
    private(set) var meanLength: Float
    
    enum ColorStrategy: Equatable, Hashable {
        case mono
        case lengthLinear
        case lengthBinary(standard: Float)
        case lengthLinearTruncated(standard: Float)
    }
    
    private(set) var colorBy: ColorStrategy = .mono
    private(set) var color1: SIMD4<Float> = [0, 0, 0, 1]
    private(set) var color2: SIMD4<Float> = [0, 0, 0, 1]
    
    private(set) var passRate: Double? = nil
    
    private var vertices: [Vertex]
    private lazy var vertexBuffer: MTLBuffer? = {
        system.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }()
    
    private func updateVertexBufferColor() {
        switch colorBy {
        case .mono:
            for i in 0..<vertices.count {
                vertices[i].color = color1
            }
            passRate = nil
        case .lengthLinear:
            let lengths = segments.map { distance($0.0, $0.1) }
            for i in 0..<vertices.count {
                let u = (lengths[i / 2] / maxLength)
                vertices[i].color = u * color1 + (1 - u) * color2
            }
            passRate = nil
        case .lengthLinearTruncated(standard: let e):
            let lengths = segments.map { distance($0.0, $0.1) }
            for i in 0..<vertices.count {
                let u: CGFloat = CGFloat(lengths[i / 2] >= e ? 1 : (lengths[i / 2] / e))
//                let c1 = Color(red: Double(color1.x), green: Double(color1.y), blue: Double(color1.z))
//                let c2 = Color(red: Double(color2.x), green: Double(color2.y), blue: Double(color2.z))
                let c1 = NSColor(calibratedRed: Double(color1.x), green: Double(color1.y), blue: Double(color1.z), alpha: 1)
                let c2 = NSColor(calibratedRed: Double(color2.x), green: Double(color2.y), blue: Double(color2.z), alpha: 1)
                var hue1 = c1.hueComponent
                var hue2 = c2.hueComponent
                if c1.hueComponent - c2.hueComponent > 0.5 {
                    hue2 = hue2 + 1
                } else if c2.hueComponent - c1.hueComponent > 0.5 {
                    hue1 = hue1 + 1
                }
                
                var hue: CGFloat = u * hue1 + (1 - u) * hue2
                if hue > 1 {
                    hue = hue - 1
                }
                let sat: CGFloat = u * c1.saturationComponent + (1 - u) * c2.saturationComponent
                let bri: CGFloat = u * c1.brightnessComponent + (1 - u) * c2.brightnessComponent
                let c = NSColor(calibratedHue: hue,
                                saturation: sat,
                                brightness: bri,
                                alpha: 1)
                vertices[i].color = .init(Float(c.redComponent), Float(c.greenComponent), Float(c.blueComponent), 1)
//                vertices[i].color = u * color1 + (1 - u) * color2
            }
            passRate = nil
        case .lengthBinary(standard: let e):
            let lengths = segments.map { distance($0.0, $0.1) }
            var lesserCount = 0
            for i in 0..<vertices.count {
                if lengths[i / 2] > e {
                    vertices[i].color = color1
                } else {
                    lesserCount = lesserCount + 1
                    vertices[i].color = color2
                }
            }
            passRate = Double(lesserCount) / Double(vertices.count)
        }
        vertexBuffer = system.device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
    }
    
    func setColorStrategy(_ strategy: ColorStrategy) {
        if colorBy == strategy { return }
        colorBy = strategy
        updateVertexBufferColor()
    }
    
    func setColor(_ color1: SIMD4<Float>, _ color2: SIMD4<Float>? = nil) {
        if (color1 == self.color1 && (color2 == nil || color2 == self.color2)) { return }
        self.color1 = color1
        if let color2 {
            self.color2 = color2
        }
        updateVertexBufferColor()
    }
    
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
        
        let lengths = segments.map { distance($0.0, $0.1) }
        self.lengths = lengths
        self.maxLength = lengths.max()!
        self.minLength = lengths.min()!
        
        var lengthSum: Float = 0
        lengths.forEach({ lengthSum = lengthSum + $0 })
        self.meanLength = lengthSum / Float(lengths.count)
    }
}
