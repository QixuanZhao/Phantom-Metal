//
//  BSplineCurve.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/6.
//

import Metal
import simd

@MainActor
@Observable
class BSplineCurve: DrawableBase {
    static var geometryPassState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.descriptor
        descriptor.vertexFunction = MetalSystem.shared.library.makeFunction(name: "spline::curveShader")
        descriptor.fragmentFunction = MetalSystem.shared.library.makeFunction(name: "geometry::lineFragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = MetalSystem.shared.hdrTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.label = "Geometry Pass Pipeline State for B-Spline Curves"
        return try! MetalSystem.shared.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    var basis: BSplineBasis
    
    private(set) var controlPoints: [SIMD4<Float>] {
        didSet {
            requireUpdate = true
        }
    }
    
    var controlPointColor: [SIMD4<Float>] {
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
    private var controlPointStartIndexBuffer: MTLBuffer?
    
    func updateBuffer() {
        if requireUpdate {
            self.controlVertexBuffer = MetalSystem.shared.device.makeBuffer(
                bytes: controlVertices,
                length: MemoryLayout<Vertex>.stride * controlPoints.count,
                options: .storageModeShared
            )
            
            let knotSpans = basis.knotSpans
            self.controlPointStartIndexBuffer = MetalSystem.shared.device.makeBuffer(
                bytes: knotSpans.map { $0.end.firstIndex - basis.order },
                length: MemoryLayout<Int>.stride * knotSpans.count
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
        
        if basis.multiplicitySum - basis.order != controlPoints.count {
            print("pass")
            return
        }
        
        encoder.setRenderPipelineState(Self.geometryPassState)
        encoder.setVertexBuffer(segmentVertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        encoder.setVertexBuffer(controlVertexBuffer, offset: 0, index: 3)
        let segmentVertexCount = Int(1 / resolution)
        for i in 0..<basis.knots.count - 1 {
            encoder.setVertexTexture(basis.basisTextures[i], index: 0)
            encoder.setVertexBuffer(controlPointStartIndexBuffer, 
                                    offset: MemoryLayout<Int>.stride * i, 
                                    index: 4)
            encoder.drawPrimitives(type: .lineStrip,
                                   vertexStart: 0,
                                   vertexCount: segmentVertexCount,
                                   instanceCount: instanceCount, baseInstance: baseInstance)
            if showControlPoints && i > 0 {
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
    
    /**
     * initialize with given basis and control points
     */
    init(basis: BSplineBasis,
         controlPoints: [SIMD4<Float>],
         showControlPoints: Bool = false) {
        self.basis = basis
        self.controlPoints = controlPoints
        self.controlPointColor = Array(repeating: [0, 0, 0, 1], count: controlPoints.count)
        self.showControlPoints = showControlPoints
        super.init()
        super.name = "B-Spline Curve"
        
        self.controlVertexBuffer = MetalSystem.shared.device.makeBuffer(bytes: controlVertices, length: MemoryLayout<Vertex>.stride * controlPoints.count, options: .storageModeShared)
        self.segmentVertexBuffer = MetalSystem.shared.device.makeBuffer(bytes: segmentVertices, length: segmentVertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)
        let knotSpans = basis.knotSpans
        self.controlPointStartIndexBuffer = MetalSystem.shared.device.makeBuffer(
            bytes: knotSpans.map { $0.end.firstIndex - basis.order },
            length: MemoryLayout<Int>.stride * knotSpans.count)
    }
    
    /**
     * create new basis against given knots and degree
     * and initialize the curve with the created basis and given control points
     */
    convenience init(knots: [BSplineBasis.Knot] = [
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
        self.init(basis: BSplineBasis(degree: degree, knots: knots),
                  controlPoints: controlPoints,
                  showControlPoints: showControlPoints)
    }
}

extension BSplineCurve {
    func clone() -> BSplineCurve {
        BSplineCurve(knots: basis.knots, controlPoints: controlPoints, degree: basis.degree, showControlPoints: showControlPoints)
    }
    
    /// Try removing the specified knot for a specified number of times (multiplicity).
    ///
    /// - Parameters:
    ///  - knotValue: value of the knot to be removed
    ///  - times: multiplicity of the knot ot be removed
    /// - Returns: the actual multiplicity removed
    @discardableResult
    func remove(knotValue u: Float, times k: Int, distanceTolerance e: Float = 1e-3) -> Int {
        
//        let alpha: (Int, Int) -> Float = { i, t in
//            return 0
//        }
        
        guard k > 0 else { return 0 }
        
        guard let indexedKnotIndex = self.basis.indexedKnots.firstIndex(where: {
            $0.knot.value == u
        }) else { return 0 }
        
        let indexedKnot = self.basis.indexedKnots[indexedKnotIndex]
        
//        let n = self.controlPoints.count - 1
        let p = self.basis.degree
//        let m = n + p + 1
        let order = self.basis.order
//        var removedMultiplicity = 0
        
//        let knotFirstIndex = indexedKnot.firstIndex
//        var knotLastIndex = indexedKnot.lastIndex
        let s = indexedKnot.knot.multiplicity
        let r = indexedKnot.lastIndex
        
        let fout = (2 * r - s - p) / 2
        var first = r - p
        var last = r - s
        
//        var knotMultiplicity = indexedKnot.knot.multiplicity
        
//        var P: [[SIMD4<Float>]] = []
//        P.append(self.controlPoints)
        
        let U = self.basis.knotVector
        var temp: [SIMD4<Float>] = .init(repeating: .zero, count: 2 * p + 1)
        
        var tp = 0
        
//        var P = self.controlPoints
        
        for t in 0..<k {
            let offset = first - 1
//            temp[0] = P[t][offset]
            temp[0] = self.controlPoints[offset]
            temp[last + 1 - offset] = self.controlPoints[last + 1]
            var i = first
            var j = last
            var ii = 1
            var jj = last - offset
            
            var remflag = false
            
            while (j - i > t) {
                let ai = (u - U[i]) / (U[i + order + t] - U[i])
                let aj = (u - U[j - t]) / (U[j + order] - U[j - t])
                
                temp[ii] = (self.controlPoints[i] - (1 - ai) * temp[ii - 1]) / ai
                temp[jj] = (self.controlPoints[j] - aj * temp[jj + 1]) / (1 - aj)
                i += 1
                ii += 1
                j -= 1
                jj -= 1
            }
            
            if (j - i < t) {
                if (distance_squared(temp[ii - 1], temp[jj + 1]) <= e * e) {
                    remflag = true
                }
            } else {
                let ai = (u - U[i]) / (U[i + order + t] - U[i])
                if (distance_squared(self.controlPoints[i], ai * temp[ii + t + 1] + (1 - ai) * temp[ii - 1]) <= e * e) {
                    remflag = true
                }
            }
            
            if (!remflag) {
                break
            } else {
                i = first
                j = last
                while (j - i > t) {
                    self.controlPoints[i] = temp[i - offset]
                    self.controlPoints[j] = temp[j - offset]
                    i += 1
                    j -= 1
                }
            }
            
            first -= 1
            last += 1
            tp += 1
        }
        
        if (tp == 0) { return 0 }
        
        if self.basis.knots[indexedKnotIndex].multiplicity > 1 {
            self.basis.knots[indexedKnotIndex].multiplicity -= 1
        } else {
            self.basis.knots.remove(at: indexedKnotIndex)
        }
        
        var j = fout
        var i = j
        
        for k in 1..<tp {
            if (k % 2 == 1) {
                i += 1
            } else {
                j -= 1
            }
        }
        
        self.controlPoints.removeSubrange(j...i)
        self.controlPointColor.removeSubrange(j...i)
        
        return tp
    }
    
    @discardableResult
    func insert(knotValue: Float) -> Bool {
        let p = basis.degree
        var knots = basis.knots
        let indexedKnots = basis.indexedKnots
        let knotVector = basis.knotVector
        var controlPoints = self.controlPoints
        
        guard !knots.isEmpty else { return false }
        guard knots.first!.value < knotValue && knotValue < knots.last!.value else { return false }
        
        guard let upperIndex = knots.firstIndex(where: { $0.value > knotValue }) else { return false }
        let lowerIndex = upperIndex - 1
        
        guard lowerIndex >= 0 else { return false }
        
        let k = indexedKnots[lowerIndex].lastIndex
        let uk = indexedKnots[lowerIndex].knot.value
        
        if uk == knotValue {
            // increment multiplicity
            guard indexedKnots[lowerIndex].knot.multiplicity < p else { return false }
            knots[lowerIndex].multiplicity = knots[lowerIndex].multiplicity + 1
        } else {
            // insert new knot
            knots.insert(.init(value: knotValue, multiplicity: 1), at: upperIndex)
        }
        
        // calculate the new control points
        controlPoints.insert(.zero, at: k - p + 1)
        
        for i in k - p + 1 ... k {
            let alpha = (knotValue - knotVector[i]) / (knotVector[i + p] - knotVector[i])
            controlPoints[i] = alpha * self.controlPoints[i] + (1 - alpha) * self.controlPoints[i - 1]
        }
        
        self.controlPoints = controlPoints
        self.controlPointColor.insert(.init(0, 0, 0, 1), at: k)
        self.basis.knots = knots
        
        return true
    }
}

extension BSplineCurve {
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
}
