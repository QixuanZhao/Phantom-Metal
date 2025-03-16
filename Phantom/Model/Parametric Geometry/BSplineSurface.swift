//
//  BSplineSurface.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/15.
//

import Metal

@MainActor
@Observable
class BSplineSurface: DrawableBase {
    static var geometryPassState: MTLRenderPipelineState = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = Vertex.patchControlPointDescriptor
        descriptor.vertexFunction = MetalSystem.shared.library.makeFunction(name: "spline::surfaceShader")
        descriptor.fragmentFunction = MetalSystem.shared.library.makeFunction(name: "geometry::fragmentShader")
//        descriptor.fragmentFunction = MetalSystem.shared.library.makeFunction(name: "geometry::patchFragmentShader")
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = MetalSystem.shared.hdrTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        descriptor.maxTessellationFactor = 64
        descriptor.isTessellationFactorScaleEnabled = false
        descriptor.tessellationControlPointIndexType = .none
        descriptor.tessellationFactorFormat = .half
        descriptor.tessellationPartitionMode = .integer
//        descriptor.tessellationPartitionMode = .pow2
        descriptor.tessellationFactorStepFunction = .constant
        descriptor.tessellationOutputWindingOrder = .counterClockwise
        descriptor.label = "Geometry Pass Pipeline State for Surfaces"
        return try! MetalSystem.shared.device.makeRenderPipelineState(descriptor: descriptor)
    }()
    
    var uBasis: BSplineBasis
    var vBasis: BSplineBasis
    
//    var uResolution: Float = 1 / Float((Int(MetalSystem.shared.width) / 16) * 16)
//    var vResolution: Float = 1 / Float((Int(MetalSystem.shared.width) / 16) * 16)
    
    var boundingBox: AxisAlignedBoundingBox {
        let initialPoint = controlNet.first!.first!
        let initialProjectedPoint = SIMD3<Float>(x: initialPoint.x / initialPoint.w,
                                                 y: initialPoint.y / initialPoint.w,
                                                 z: initialPoint.z / initialPoint.w)
        var minPoint: SIMD3<Float> = initialProjectedPoint
        var maxPoint: SIMD3<Float> = initialProjectedPoint
        for i in 0..<controlNet.count {
            for j in 0..<controlNet[i].count {
                let point = controlNet[i][j]
                let projectedPoint = SIMD3<Float>(x: point.x / point.w, y: point.y / point.w, z: point.z / point.w)
                
                minPoint = .init(x: min(minPoint.x, projectedPoint.x),
                                 y: min(minPoint.y, projectedPoint.y),
                                 z: min(minPoint.z, projectedPoint.z))
                
                maxPoint = .init(x: max(maxPoint.x, projectedPoint.x),
                                 y: max(maxPoint.y, projectedPoint.y),
                                 z: max(maxPoint.z, projectedPoint.z))
            }
        }
        return .init(diagonalVertices: (minPoint, maxPoint))
    }
    
    private(set) var controlNet: [[SIMD4<Float>]] {
        didSet { requireUpdate = true }
    }
    
    private(set) var controlPointColor: [[SIMD4<Float>]] {
        didSet { requireUpdate = true }
    }
    
    var controlVertices: [Vertex] {
        var result: [Vertex] = []
        for (i, points) in controlNet.enumerated() {
            for (j, point) in points.enumerated() {
                result.append(Vertex(position: [point.x, point.y, point.z],
                                     color: controlPointColor[i][j]))
            }
        }
        return result
    }
    
    private var requireUpdate = true
    var showControlNet: Bool = false
    
    private var tessellationFactorBuffer: MTLBuffer = {
        let buffer = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<MTLQuadTessellationFactorsHalf>.size)!
        buffer.label = "B-Spline Surface Tessellation Factor Buffer"
        return buffer
    }()
    
    
    private var requireFactorsFill = true
    var edgeTessellationFactors: SIMD4<Float> = [64, 64, 64, 64] {
        didSet { requireFactorsFill = true }
    }
    var insideTessellationFactors: SIMD2<Float> = [64, 64] {
        didSet { requireFactorsFill = true }
    }
    
    private var controlVertexBuffer: MTLBuffer?
    private var controlLineStripIndexBufferI: MTLBuffer
    private var controlLineStripIndexBufferJ: MTLBuffer
    
    func updateBuffer() {
        if requireUpdate {
            let vertices = controlVertices
            self.controlVertexBuffer = MetalSystem.shared.device.makeBuffer(bytes: vertices,
                                                                length: MemoryLayout<Vertex>.stride * vertices.count)
            
            let iControlPointCount = uBasis.multiplicitySum - uBasis.order
            let jControlPointCount = vBasis.multiplicitySum - vBasis.order
            let controlPointCount = iControlPointCount * jControlPointCount
            var iStripIndices: [UInt16] = Array(repeating: 0, count: controlPointCount)
            var jStripIndices: [UInt16] = Array(repeating: 0, count: controlPointCount)
            
            for j in 0..<jControlPointCount {
                for i in 0..<iControlPointCount {
                    iStripIndices[j * iControlPointCount + i] = UInt16(j * iControlPointCount + i)
                    jStripIndices[i * jControlPointCount + j] = UInt16(j * iControlPointCount + i)
                }
            }
            
            self.controlLineStripIndexBufferI = MetalSystem.shared.device.makeBuffer(bytes: iStripIndices, length: controlPointCount * 16)!
            self.controlLineStripIndexBufferJ = MetalSystem.shared.device.makeBuffer(bytes: jStripIndices, length: controlPointCount * 16)!
            requireUpdate = false
        }
    }
    
    func setControlPointComponent(at ji: (Int, Int), _ component: Float, componentIndex: Int) {
        controlNet[ji.0][ji.1][componentIndex] = component
    }
    
    func setControlPoint(at ji: (Int, Int), _ point: SIMD4<Float>) {
        controlNet[ji.0][ji.1] = point
    }
    
    func setControlPointColor(at ji: (Int, Int), _ color: SIMD4<Float>) {
        controlPointColor[ji.0][ji.1] = color
    }
    
    
    /// remove v knot for the specified number of times
    ///
    /// - Parameters:
    ///   - vKnot: the v knot to be removed
    ///   - for: the expected multiplicity to be removed
    ///   - withTolerance: the distance tolerance used by knot removal algorithm
    /// - Returns: the actual multiplicity removed
    @discardableResult
    func remove(vKnot v: Float, for times: Int, withTolerance e: Float = 1e-6) -> Int {
        var intermediateCurves: [BSplineCurve] = []
        let curveCount = uBasis.multiplicitySum - uBasis.order
        for i in 0..<curveCount {
            let curve = BSplineCurve(knots: vBasis.knots, controlPoints: controlNet.map { $0[i] }, degree: vBasis.degree)
            intermediateCurves.append(curve)
        }
        
        let removedMultiplicity = intermediateCurves.map {
            $0.remove(knotValue: v, times: times, distanceTolerance: e)
        }
        
        guard let actuallyRemovedMultiplicity = removedMultiplicity.min() else { return 0 }
        
        for i in 0..<curveCount {
            if removedMultiplicity[i] != actuallyRemovedMultiplicity {
                let curve = BSplineCurve(knots: vBasis.knots, controlPoints: controlNet.map { $0[i] }, degree: vBasis.degree)
                intermediateCurves[i] = curve
                do {
                    let tp = curve.remove(knotValue: v, times: actuallyRemovedMultiplicity, distanceTolerance: e)
                    guard tp == actuallyRemovedMultiplicity else {
                        throw PhantomError.unknown("actually removed multiplicity does not match")
                    }
                } catch {
                    print(error.localizedDescription)
                    return 0
                }
            }
        }
        
        var newControlNet: [[SIMD4<Float>]] = .init(repeating: .init(repeating: .zero, count: curveCount), count: intermediateCurves.first!.controlPoints.count)
        for i in 0..<curveCount {
            let curve = intermediateCurves[i]
            for j in 0..<curve.controlPoints.count {
                newControlNet[j][i] = curve.controlPoints[j]
            }
        }
        
        controlNet = newControlNet
        controlPointColor.removeLast(actuallyRemovedMultiplicity)
        vBasis = intermediateCurves.first!.basis
        
        return actuallyRemovedMultiplicity
    }
    
    /// remove u knot for the specified number of times
    ///
    /// - Parameters:
    ///   - uKnot: the u knot to be removed
    ///   - for: the expected multiplicity to be removed
    ///   - withTolerance: the distance tolerance used by knot removal algorithm
    /// - Returns: the actual multiplicity removed
    @discardableResult
    func remove(uKnot u: Float, for times: Int, withTolerance e: Float = 1e-6) -> Int {
        var intermediateCurves = controlNet.map { controlPoints in
            BSplineCurve(knots: uBasis.knots, controlPoints: controlPoints, degree: uBasis.degree)
        }
        
        let removedMultiplicity = intermediateCurves.map {
            $0.remove(knotValue: u, times: times, distanceTolerance: e)
        }
        
        guard let actuallyRemovedMultiplicity = removedMultiplicity.min() else { return 0 }
        
        intermediateCurves = controlNet.map { controlPoints in
            BSplineCurve(knots: uBasis.knots, controlPoints: controlPoints, degree: uBasis.degree)
        }
        
        do {
            try intermediateCurves.forEach { curve in
                let tp = curve.remove(knotValue: u, times: actuallyRemovedMultiplicity, distanceTolerance: e)
                guard tp == actuallyRemovedMultiplicity else {
                    throw PhantomError.unknown("actually removed multiplicity does not match")
                }
            }
        } catch {
            print(error.localizedDescription)
            return 0
        }
        
        controlNet = intermediateCurves.map { $0.controlPoints }
        for i in 0..<controlPointColor.count {
            controlPointColor[i].removeLast(actuallyRemovedMultiplicity)
        }
        uBasis = intermediateCurves.first!.basis
        
        return actuallyRemovedMultiplicity
    }
    
    @discardableResult
    func insert(uKnot u: Float) -> Bool {
        let p = uBasis.degree
        var knots = uBasis.knots
        let indexedKnots = uBasis.indexedKnots
        let knotVector = uBasis.knotVector
        var controlNet = self.controlNet
        
        guard !knots.isEmpty else { return false }
        guard knots.first!.value < u && u < knots.last!.value else { return false }
        
        guard let upperIndex = knots.firstIndex(where: { $0.value > u }) else { return false }
        let lowerIndex = upperIndex - 1
        
        guard lowerIndex >= 0 else { return false }
        
        let k = indexedKnots[lowerIndex].lastIndex
        let uk = indexedKnots[lowerIndex].knot.value
        
        if uk == u {
            // increment multiplicity
            guard indexedKnots[lowerIndex].knot.multiplicity < p else { return false }
            knots[lowerIndex].multiplicity = knots[lowerIndex].multiplicity + 1
        } else {
            // insert new knot
            knots.insert(.init(value: u, multiplicity: 1), at: upperIndex)
        }
        
        // calculate the new control points
        for j in 0..<controlNet.count {
            controlNet[j].insert(.zero, at: k - p + 1)
            for i in k - p + 1 ... k {
                let alpha = (u - knotVector[i]) / (knotVector[i + p] - knotVector[i])
                controlNet[j][i] = alpha * self.controlNet[j][i] + (1 - alpha) * self.controlNet[j][i - 1]
            }
            
            self.controlPointColor[j].insert(.init(.zero, 1), at: k)
        }
        
        self.controlNet = controlNet
        self.uBasis.knots = knots
        
        return true
    }
    
    @discardableResult
    func insert(vKnot v: Float) -> Bool {
        let q = vBasis.degree
        var knots = vBasis.knots
        let indexedKnots = vBasis.indexedKnots
        let knotVector = vBasis.knotVector
        var controlNet = self.controlNet
        
        guard !knots.isEmpty else { return false }
        guard knots.first!.value < v && v < knots.last!.value else { return false }
        
        guard let upperIndex = knots.firstIndex(where: { $0.value > v }) else { return false }
        let lowerIndex = upperIndex - 1
        
        guard lowerIndex >= 0 else { return false }
        
        let k = indexedKnots[lowerIndex].lastIndex
        let vk = indexedKnots[lowerIndex].knot.value
        
        if vk == v {
            // increment multiplicity
            guard indexedKnots[lowerIndex].knot.multiplicity < q else { return false }
            knots[lowerIndex].multiplicity = knots[lowerIndex].multiplicity + 1
        } else {
            // insert new knot
            knots.insert(.init(value: v, multiplicity: 1), at: upperIndex)
        }
        
        // calculate the new control points
        let iControlPointCount = uBasis.multiplicitySum - uBasis.order
//        let jControlPointCount = vBasis.multiplicitySum - vBasis.order
        controlNet.insert(.init(repeating: .zero,
                                count: iControlPointCount),
                          at: k - q + 1)
        for j in 0..<iControlPointCount {
            for i in k - q + 1 ... k {
                let alpha = (v - knotVector[i]) / (knotVector[i + q] - knotVector[i])
                controlNet[i][j] = alpha * self.controlNet[i][j] + (1 - alpha) * self.controlNet[i - 1][j]
            }
        }
        
        self.controlPointColor.insert(.init(repeating: .init(.zero, 1), count: iControlPointCount), at: k)
        self.controlNet = controlNet
        self.vBasis.knots = knots
        
        return true
    }
    
    override func draw(_ encoder: MTLRenderCommandEncoder, 
                       instanceCount: Int = 1,
                       baseInstance: Int = 0) {
        
        if requireFactorsFill {
            Tessellator.fillFactors(
                buffer: tessellationFactorBuffer,
                edgeFactors: edgeTessellationFactors,
                insideFactors: insideTessellationFactors
            )
            requireFactorsFill = false
        }
        
        updateBuffer()
        uBasis.updateTexture()
        vBasis.updateTexture()
        
        encoder.setRenderPipelineState(Self.geometryPassState)
        encoder.setVertexBuffer(Quad.vertexBuffer, offset: 0, index: BufferPosition.vertex.rawValue)
        encoder.setTessellationFactorBuffer(tessellationFactorBuffer, offset: 0, instanceStride: 0)
        encoder.setVertexBuffer(controlVertexBuffer, offset: 0, index: 3)
        let uSpans = uBasis.knotSpans
        let vSpans = vBasis.knotSpans
        let iControlPointCount = uBasis.multiplicitySum - uBasis.order
        let jControlPointCount = vBasis.multiplicitySum - vBasis.order
        for (i, uSpan) in uSpans.enumerated() {
            encoder.setVertexTexture(uBasis.basisTextures[i], index: 0)
            for (j, vSpan) in vSpans.enumerated() {
                encoder.setVertexTexture(vBasis.basisTextures[j], index: 1)
                encoder.setVertexBytes([Int32(uSpan.end.firstIndex - uBasis.order),
                                        Int32(vSpan.end.firstIndex - vBasis.order),
                                        Int32(iControlPointCount),
                                        Int32(jControlPointCount)],
                                       length: MemoryLayout<Int32>.stride * 4,
                                       index: 4)
                
                encoder.drawPatches(numberOfPatchControlPoints: 4, patchStart: 0, patchCount: 1,
                                    patchIndexBuffer: nil, patchIndexBufferOffset: 0,
                                    instanceCount: instanceCount, baseInstance: baseInstance)
            }
        }
        
        if showControlNet {
            encoder.setRenderPipelineState(Axes.geometryPassState)
            encoder.setVertexBuffer(controlVertexBuffer, offset: 0, index: 0)
            for j in 0..<jControlPointCount {
                encoder.drawIndexedPrimitives(type: .lineStrip, indexCount: iControlPointCount, indexType: .uint16,
                                              indexBuffer: controlLineStripIndexBufferI, indexBufferOffset: j * iControlPointCount * 2,
                                              instanceCount: instanceCount, baseVertex: 0, baseInstance: baseInstance)
            }
            for i in 0..<iControlPointCount {
                encoder.drawIndexedPrimitives(type: .lineStrip, indexCount: jControlPointCount, indexType: .uint16,
                                              indexBuffer: controlLineStripIndexBufferJ, indexBufferOffset: i * jControlPointCount * 2,
                                              instanceCount: instanceCount, baseVertex: 0, baseInstance: baseInstance)
            }
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: jControlPointCount * iControlPointCount,
                                   instanceCount: instanceCount, baseInstance: baseInstance)
        }
    }
    
    init(uBasis: BSplineBasis,
         vBasis: BSplineBasis,
         controlNet: [[SIMD4<Float>]],
         controlPointColor: [[SIMD4<Float>]]) {
        self.uBasis = uBasis
        self.vBasis = vBasis
        self.controlNet = controlNet
        self.controlPointColor = controlPointColor
        
        let iControlPointCount = uBasis.multiplicitySum - uBasis.order
        let jControlPointCount = vBasis.multiplicitySum - vBasis.order
        let controlPointCount = iControlPointCount * jControlPointCount
        var iStripIndices: [UInt16] = Array(repeating: 0, count: controlPointCount)
        var jStripIndices: [UInt16] = Array(repeating: 0, count: controlPointCount)
        
        for j in 0..<jControlPointCount {
            for i in 0..<iControlPointCount {
                iStripIndices[j * iControlPointCount + i] = UInt16(j * iControlPointCount + i)
                jStripIndices[i * jControlPointCount + j] = UInt16(j * iControlPointCount + i)
            }
        }
        
        self.controlLineStripIndexBufferI = MetalSystem.shared.device.makeBuffer(bytes: iStripIndices, length: controlPointCount * 16)!
        self.controlLineStripIndexBufferJ = MetalSystem.shared.device.makeBuffer(bytes: jStripIndices, length: controlPointCount * 16)!
        
        super.init()
        super.name = "B-Spline Surface"
    }
    
    convenience init(uKnots: [BSplineBasis.Knot] = [
                        .init(value: 0, multiplicity: 4),
                        .init(value: 0.5, multiplicity: 1),
                        .init(value: 0.7, multiplicity: 1),
                        .init(value: 1, multiplicity: 4),
                    ],
                     vKnots: [BSplineBasis.Knot] = [
                        .init(value: 0, multiplicity: 4),
                        .init(value: 0.5, multiplicity: 1),
                        .init(value: 1, multiplicity: 4),
                    ],
                     degrees: (Int, Int) = (3, 3),
                     controlNet: [[SIMD4<Float>]] = [
                        [
                            [-4, 0, 0, 1] - 4,
                            [-3, 0, 0, 1] - 4,
                            [-1, 0, 0, 1] - 4,
                            [1, 0, 0, 1] - 4,
                            [3, 0, 1, 1] - 4,
                            [5, 0, 0, 1] - 4,
                        ],
                        [
                            [-4, 0, 0, 1] - 2,
                            [-3, 2, 0, 1] - 2,
                            [-1, 0, 2, 1] - 2,
                            [1, 0, 0, 1] - 2,
                            [3, -2, 0, 1] - 2,
                            [5, 0, 3, 1] - 2,
                        ],
                        [
                            [-4, 0, 0, 1],
                            [-3, 2, 0, 1],
                            [-1, 0, 2, 1],
                            [1, 0, 0, 1],
                            [3, -2, 0, 1],
                            [5, 0, 3, 1],
                        ],
                        [
                            [-4, 0, 0, 1] + 2,
                            [-3, 2, 0, 1] + 2,
                            [-1, 0, 2, 1] + 2,
                            [1, 0, 0, 1] + 2,
                            [3, -2, 0, 1] + 2,
                            [5, 0, 3, 1] + 2,
                        ],
                        [
                            [-4, 0, 0, 1] + 4,
                            [-3, 2, 0, 1] + 4,
                            [-1, 0, 2, 1] + 4,
                            [1, 0, 0, 1] + 4,
                            [3, 0, 0, 1] + 4,
                            [5, 0, 3, 1] + 4,
                        ],
                     ]
    ) {
        self.init(uBasis: BSplineBasis(degree: degrees.0, knots: uKnots),
                  vBasis: BSplineBasis(degree: degrees.1, knots: vKnots),
                  controlNet: controlNet,
                  controlPointColor: controlNet.map { $0.map { _ in [0,0,0,1] } })
    }
}
