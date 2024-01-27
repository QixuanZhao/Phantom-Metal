//
//  BézeirCurve.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import Metal

class BézeirCurve: DrawableBase {
    static var geometryPassState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.descriptor
        descriptor.vertexFunction = system.library.makeFunction(name: "bernstein::bézeirCurveShader")
        descriptor.fragmentFunction = system.library.makeFunction(name: "geometry::lineFragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = system.hdrTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = system.positionTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = system.normalTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = system.albedoSpecularTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = system.refractiveIndicesRoughnessUTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = system.extinctionCoefficentsRoughnessVTexture.pixelFormat
        descriptor.label = "Geometry Pass Pipeline State for Bézeir Curves"
        return try! system.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    var basis: BernsteinBasis
    
    private(set) var controlPoints: [SIMD4<Float>] {
        didSet {
            requireUpdate = true
        }
    }
    
    private(set) var controlPointColor: [SIMD4<Float>] {
        didSet {
            requireUpdate = true
        }
    }
    
    var resolution: Float = 1 / Float((Int(system.width) / 16) * 16)
    
    var segmentVertices: [Vertex] {
        let count = Int(1 / resolution)
        var result: [Vertex] = []
        for i in 0..<count {
            let fraction = Float(i) * 1.0 / Float(count - 1)
            result.append(Vertex(position: [fraction, 0, 0], parameter: [fraction, 0], color: .one))
        }
        return result
    }
    
    var segmentVertexBuffer: MTLBuffer?
    
    private var requireUpdate = true
    
    var showControlPoints: Bool
    
    var controlVertices: [Vertex] {
        var result: [Vertex] = []
        for (i, point) in controlPoints.enumerated() {
            result.append(Vertex(position: [point.x, point.y, point.z],
                                 color: controlPointColor[i]))
        }
        return result
    }
    
    private var controlVertexBuffer: MTLBuffer?
    
    func updateBuffer() {
        if requireUpdate {
            self.controlVertexBuffer = system.device.makeBuffer(bytes: controlVertices,
                                                                length: MemoryLayout<Vertex>.stride * controlPoints.count,
                                                                options: .storageModeShared)
            requireUpdate = false
        }
    }
    
    func setControlPointComponent(at index: Int, _ component: Float, componentIndex: Int) {
        controlPoints[index][componentIndex] = component
    }
    
    func setControlPoint(at index: Int, _ point: SIMD4<Float>) {
        controlPoints[index] = point
    }
    
    func setControlPointColor(at index: Int, _ color: SIMD4<Float>) {
        controlPointColor[index] = color
    }
    
    override func draw(_ encoder: MTLRenderCommandEncoder,
                       instanceCount: Int = 1,
                       baseInstance: Int = 0) {
        updateBuffer()
        basis.updateTexture()
        
        encoder.setRenderPipelineState(Self.geometryPassState)
        encoder.setVertexBuffer(segmentVertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        encoder.setVertexBuffer(controlVertexBuffer, offset: 0, index: 3)
        let segmentVertexCount = Int(1 / resolution)
        
        encoder.setVertexTexture(basis.basisTexture, index: 0)
        encoder.drawPrimitives(type: .lineStrip,
                               vertexStart: 0,
                               vertexCount: segmentVertexCount,
                               instanceCount: instanceCount, baseInstance: baseInstance)
        
        if showControlPoints {
            encoder.setRenderPipelineState(Axes.geometryPassState)
            encoder.setVertexBuffer(controlVertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
            encoder.drawPrimitives(type: .lineStrip,
                                   vertexStart: .zero,
                                   vertexCount: controlVertices.count,
                                   instanceCount: instanceCount,
                                   baseInstance: baseInstance)
            encoder.drawPrimitives(type: .point,
                                   vertexStart: .zero,
                                   vertexCount: controlVertices.count,
                                   instanceCount: instanceCount,
                                   baseInstance: baseInstance)
        }
    }
    
    init(controlPoints: [SIMD4<Float>]  = [
            [-5, 0, 0, 1],
            [-4, 2, 0, 1],
            [-2, -2, -2, 1],
            [0, 1, 4, 1]
         ],
         degree: Int = 3,
         showControlPoints: Bool = false) {
        self.basis = BernsteinBasis(degree: degree)
        self.controlPoints = controlPoints
        self.controlPointColor = Array(repeating: .one, count: controlPoints.count)
        self.showControlPoints = showControlPoints
        super.init()
        super.name = "Bézeir Curve"
        
        self.controlVertexBuffer = system.device.makeBuffer(bytes: controlVertices, length: MemoryLayout<Vertex>.stride * controlPoints.count, options: .storageModeShared)
        self.segmentVertexBuffer = system.device.makeBuffer(bytes: segmentVertices, length: segmentVertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)
    }
}
