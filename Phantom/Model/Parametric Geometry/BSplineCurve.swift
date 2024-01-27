//
//  BSplineCurve.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/6.
//

import Metal

@Observable
class BSplineCurve: DrawableBase {
    static var geometryPassState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.descriptor
        descriptor.vertexFunction = system.library.makeFunction(name: "spline::curveShader")
        descriptor.fragmentFunction = system.library.makeFunction(name: "geometry::lineFragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = system.hdrTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = system.positionTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = system.normalTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = system.albedoSpecularTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = system.refractiveIndicesRoughnessUTexture.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = system.extinctionCoefficentsRoughnessVTexture.pixelFormat
        descriptor.label = "Geometry Pass Pipeline State for B-Spline Curves"
        return try! system.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    var basis: BSplineBasis
    
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
    private var controlPointStartIndexBuffer: MTLBuffer?
    
    func updateBuffer() {
        if requireUpdate {
            self.controlVertexBuffer = system.device.makeBuffer(bytes: controlVertices, 
                                                                length: MemoryLayout<Vertex>.stride * controlPoints.count,
                                                                options: .storageModeShared)
            
            let knotSpans = basis.knotSpans
            self.controlPointStartIndexBuffer = system.device.makeBuffer(bytes: knotSpans.map { $0.end.firstIndex - basis.order },
                                                                         length: MemoryLayout<Int>.stride * knotSpans.count)
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
    
    @discardableResult
    func insert(knot: Float) -> Bool {
        let p = basis.degree
        var knots = basis.knots
        let indexedKnots = basis.indexedKnots
        let knotVector = basis.knotVector
        var controlPoints = self.controlPoints
        
        guard !knots.isEmpty else { return false }
        guard knots.first!.value < knot && knot < knots.last!.value else { return false }
        
        guard let upperIndex = knots.firstIndex(where: { $0.value > knot }) else { return false }
        let lowerIndex = upperIndex - 1
        
        guard lowerIndex >= 0 else { return false }
        
        let k = indexedKnots[lowerIndex].lastIndex
//        let k1 = indexedKnots[upperIndex].firstIndex
        
        let uk = indexedKnots[lowerIndex].knot.value
//        let uk1 = indexedKnots[upperIndex].knot.value
        
        if uk == knot {
            // increment multiplicity
            guard indexedKnots[lowerIndex].knot.multiplicity < p else { return false }
            knots[lowerIndex].multiplicity = knots[lowerIndex].multiplicity + 1
        } else {
            // insert new knot
            knots.insert(.init(value: knot, multiplicity: 1), at: upperIndex)
        }
        
        // calculate the new control points
        controlPoints.insert(.zero, at: k - p + 1)
        
        for i in k - p + 1 ... k {
            let alpha = (knot - knotVector[i]) / (knotVector[i + p] - knotVector[i])
            controlPoints[i] = alpha * self.controlPoints[i] + (1 - alpha) * self.controlPoints[i - 1]
        }
        
        self.controlPoints = controlPoints
        self.controlPointColor.insert(.one, at: k)
        self.basis.knots = knots
        
        return true
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
        for i in 0..<basis.knots.count - 1 {
            encoder.setVertexTexture(basis.basisTextures[i], index: 0)
            encoder.setVertexBuffer(controlPointStartIndexBuffer, offset: MemoryLayout<Int>.stride * i, index: 4)
            encoder.drawPrimitives(type: .lineStrip,
                                   vertexStart: 0,
                                   vertexCount: segmentVertexCount,
                                   instanceCount: instanceCount, baseInstance: baseInstance)
            if i > 0 {
                encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 1, 
                                       instanceCount: instanceCount, baseInstance: baseInstance)
            }
        }
        
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
    
    init(knots: [BSplineBasis.Knot] = [
            .init(value: 0, multiplicity: 4),
            .init(value: 0.5, multiplicity: 2),
            .init(value: 1, multiplicity: 4),
        ],
         controlPoints: [SIMD4<Float>]  = [
            [-5, 0, 0, 1],
            [-4, 2, 0, 1],
            [-2, -2, -2, 1],
            [0, 1, 4, 1],
            [2.5, -3, 1.2, 1],
            [5, 0, 0, 1]
         ],
         degree: Int = 3,
         showControlPoints: Bool = false) {
        self.basis = BSplineBasis(degree: degree, knots: knots)
        self.controlPoints = controlPoints
        self.controlPointColor = Array(repeating: .one, count: controlPoints.count)
        self.showControlPoints = showControlPoints
        super.init()
        super.name = "B-Spline Curve"
        
        self.controlVertexBuffer = system.device.makeBuffer(bytes: controlVertices, length: MemoryLayout<Vertex>.stride * controlPoints.count, options: .storageModeShared)
        self.segmentVertexBuffer = system.device.makeBuffer(bytes: segmentVertices, length: segmentVertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)
        let knotSpans = basis.knotSpans
        self.controlPointStartIndexBuffer = system.device.makeBuffer(bytes: knotSpans.map { $0.end.firstIndex - basis.order },
                                                                     length: MemoryLayout<Int>.stride * knotSpans.count)
    }
}
