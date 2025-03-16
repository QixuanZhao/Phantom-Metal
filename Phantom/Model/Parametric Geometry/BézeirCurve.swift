//
//  BézeirCurve.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import Metal

@MainActor
@Observable
class BézierCurve: DrawableBase {
    static var geometryPassState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.descriptor
        descriptor.vertexFunction = MetalSystem.shared.library.makeFunction(name: "bernstein::bézeirCurveShader")
        descriptor.fragmentFunction = MetalSystem.shared.library.makeFunction(name: "geometry::lineFragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = MetalSystem.shared.hdrTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.label = "Geometry Pass Pipeline State for Bézeir Curves"
        return try! MetalSystem.shared.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    var basis: BernsteinBasis
    
    var boundingBox: AxisAlignedBoundingBox {
        let initialPoint = controlPoints.first!
        let initialProjectedPoint = SIMD3<Float>(x: initialPoint.x / initialPoint.w,
                                                 y: initialPoint.y / initialPoint.w,
                                                 z: initialPoint.z / initialPoint.w)
        var minPoint: SIMD3<Float> = initialProjectedPoint
        var maxPoint: SIMD3<Float> = initialProjectedPoint
        for i in 1..<controlPoints.count {
            let point = controlPoints[i]
            let projectedPoint = SIMD3<Float>(x: point.x / point.w, y: point.y / point.w, z: point.z / point.w)
            
            minPoint = .init(x: min(minPoint.x, projectedPoint.x),
                             y: min(minPoint.y, projectedPoint.y),
                             z: min(minPoint.z, projectedPoint.z))
            
            maxPoint = .init(x: max(maxPoint.x, projectedPoint.x),
                             y: max(maxPoint.y, projectedPoint.y),
                             z: max(maxPoint.z, projectedPoint.z))
        }
        return .init(diagonalVertices: (minPoint, maxPoint))
    }
    
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
    
    var resolution: Float = 1 / Float((Int(MetalSystem.shared.width) / 16) * 16)
    
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
            self.controlVertexBuffer = MetalSystem.shared.device.makeBuffer(
                bytes: controlVertices,
                length: MemoryLayout<Vertex>.stride * controlPoints.count,
                options: .storageModeShared
            )
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
        self.controlPointColor = Array(repeating: [0, 0, 0, 1], count: controlPoints.count)
        self.showControlPoints = showControlPoints
        super.init()
        super.name = "Bézeir Curve"
        
        self.controlVertexBuffer = MetalSystem.shared.device.makeBuffer(bytes: controlVertices, length: MemoryLayout<Vertex>.stride * controlPoints.count, options: .storageModeShared)
        self.segmentVertexBuffer = MetalSystem.shared.device.makeBuffer(bytes: segmentVertices, length: segmentVertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)
    }
}
