//
//  BSplineApproximator.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/1.
//

import Foundation
import MetalPerformanceShaders

extension BSplineBasis {
    
    /// fill given number of knots in the given knot vector
    ///
    /// New knots are evenly spaced in the knot vector.
    /// - parameters:
    ///  - knots: the given knot vector
    ///  - count: the number of knots to be inserted
    /// - returns: new knot vector
    static func fillKnots(in knots: [Knot], count: Int = 0) -> [Knot] {
        if count < 1 { return knots }
        
        let N = count + knots.count - 1
        
        var result = knots
        let spans = (1..<knots.count).map { knots[$0 - 1].value...knots[$0].value }
        let spanLengths = spans.map { $0.upperBound - $0.lowerBound }
        let spanInsertionFactors = spanLengths.map { $0 * Float(N) - 1 }
        var spanInsertionCounts = spanInsertionFactors.map { Int($0) }
        
        var spanInsertionCountSum = 0
        spanInsertionCounts.forEach { spanInsertionCountSum += $0 }
        
        let remainder = count - spanInsertionCountSum
        
        if remainder > 0 {
            let spanRemainderFactors: [(Int, Float)] = (0..<spanInsertionFactors.count).map { i in
                (i, spanInsertionFactors[i] - Float(spanInsertionCounts[i]))
            }.sorted { $0.1 > $1.1 }
            
            for k in 0..<remainder {
                let i = spanRemainderFactors[k].0
                spanInsertionCounts[i] += 1
            }
        }
        
        for i in (0..<spanInsertionCounts.count).reversed() {
            let c = spanInsertionCounts[i]
            if c > 0 {
                let span = spans[i]
                let l = spanLengths[i]
                let subLength = l / Float(c + 1)
                var tempL = span.lowerBound
                for j in 1...c {
                    let knot = tempL + subLength
                    result.insert(.init(value: knot, multiplicity: 1), at: i + j)
                    tempL = knot
                }
            }
        }
        
        return result
    }
    
    func sample() -> [Float] {
        let knotVector = knotVector
        var sum: Float = 0
        var samples: [Float] = []
        for k in order ..< knotVector.count {
            sum = sum + knotVector[k]
            samples.append(sum / Float(order + 1))
            sum = sum - knotVector[k - order]
        }
        
        return samples
    }
    
    static func fillSamples(_ samples: [Float]) -> [Float] {
        var result = samples.map { [$0, $0] }.flatMap { $0 }
        result.removeLast()
        for i in 0..<result.count {
            if i % 2 == 1 {
                result[i] = (result[i] + result[i + 1]) / 2
            }
        }
        return result
    }
}

@MainActor
class BSplineApproximator {
    static private var surfaceMatrixFillerState: MTLComputePipelineState = {
        return try! MetalSystem.shared.device.makeComputePipelineState(function: MetalSystem.shared.library.makeFunction(name: "surfaceFiller")!)
    }()
    
    static private var uIsoCurveConstraintFiller: MTLComputePipelineState = {
        return try! MetalSystem.shared.device.makeComputePipelineState(function: MetalSystem.shared.library.makeFunction(name: "uIsoCurveConstraintFiller")!)
    }()
    
    static private var vIsoCurveConstraintFiller: MTLComputePipelineState = {
        return try! MetalSystem.shared.device.makeComputePipelineState(function: MetalSystem.shared.library.makeFunction(name: "vIsoCurveConstraintFiller")!)
    }()
    
    struct GuidanceResult {
        let originalSurface: BSplineSurface
        let modifiedSurface: BSplineSurface
        let averageError: Float
        let maxError: Float
    }
    
    /// Generate a knot vector with capacity for bi-directional constraints
    static func biconstrainedKnots(for isoP: [Float] = [0, 1],
                                   degree p: Int = 3) -> [BSplineBasis.Knot] {
        let averageKnots = BSplineBasis.averageKnots(for: isoP, withDegree: p)
        let filledKnots = BSplineBasis.fillKnots(in: averageKnots, count: isoP.count + 1)
        return filledKnots
    }
    
    /// Generate a deviation surface (or offset surface).
    ///
    /// - parameter uDegree: the degree _p_ for knot vector _U_
    /// - parameter vDegree: the degree _q_ for knot vector _V_
    /// - parameter sampleDeviation: the parameterized sample vectors to be fitted
    /// - parameter isoU: the _u_ values where the corresponding v-curves are to be fixed (including boundary curves)
    /// - parameter isoV: the _v_ values where the corresponding u-curves are to be fixed (including boundary curves)
    ///
    /// - returns: a ``Result`` instance associated with the desired ``BSplineSurface``
    static func generateDeviationSurface(
        uDegree p: Int,
        vDegree q: Int,
        sampleDeviation: [(SIMD2<Float>, SIMD3<Float>)],
        isoU: [Float] = [0, 1],
        isoV: [Float] = [0, 1]
    ) -> Result<BSplineSurface, Error> {
        var innerIsoU = isoU
        var innerIsoV = isoV
        
        innerIsoU.removeFirst()
        innerIsoU.removeLast()
        innerIsoV.removeFirst()
        innerIsoV.removeLast()
        
        let blendUKnots = biconstrainedKnots(for: isoU, degree: p)
        let blendVKnots = biconstrainedKnots(for: isoV, degree: q)
        
        let blendUBasis = BSplineBasis(degree: p, knots: blendUKnots)
        let blendVBasis = BSplineBasis(degree: q, knots: blendVKnots)
        
        return generateDeviationSurface(blendUBasis: blendUBasis,
                                        blendVBasis: blendVBasis,
                                        sampleDeviation: sampleDeviation,
                                        innerIsoU: innerIsoU,
                                        innerIsoV: innerIsoV)
    }
    
    /// Generate a deviation surface (or offset surface).
    ///
    /// - parameter blendUBasis: the basis determined by knot vector _U_
    /// - parameter blendVBasis: the basis determined by knot vector _V_
    /// - parameter sampleDeviation: the parameterized sample vectors to be fitted
    /// - parameter innerIsoU: the inner _u_ values where the corresponding v-curves are to be fixed
    /// - parameter innerIsoV: the inner _v_ values where the corresponding u-curves are to be fixed
    ///
    /// - returns: a ``Result`` instance associated with the desired ``BSplineSurface``
    static func generateDeviationSurface(
        blendUBasis: BSplineBasis,
        blendVBasis: BSplineBasis,
        sampleDeviation: [(SIMD2<Float>, SIMD3<Float>)],
        innerIsoU: [Float] = [],
        innerIsoV: [Float] = []
    ) -> Result<BSplineSurface, Error> {
        
        let blankUSamples = blendUBasis.sample()
        let blankVSamples = blendVBasis.sample()
        
        let givenSamples: [(SIMD2<Float>, SIMD3<Float>, Float)]
            = sampleDeviation.map { ($0.0, $0.1, 1) }
        
        var samples: [(SIMD2<Float>, SIMD3<Float>, Float)] = []
        for u in blankUSamples {
            for v in blankVSamples {
                var nearestDistance: Float = 1
                givenSamples.forEach { nearestDistance = min(nearestDistance, distance_squared($0.0, [u, v])) }
                samples.append(([u, v], .zero, nearestDistance))
            }
        }
        samples.append(contentsOf: givenSamples)
        
        let uControlPointCount = blendUBasis.multiplicitySum - blendUBasis.order
        let vControlPointCount = blendVBasis.multiplicitySum - blendVBasis.order
        
        let controlPointCount = uControlPointCount * vControlPointCount
        
        // unconstrained equation NP = S, weights are W
        // constrained equation MP = T
        var weights: [Float] = Array<Float>(repeating: 0, count: samples.count * samples.count)
        for i in 0..<samples.count {
            weights[i * samples.count + i] = samples[i].2
        }
        let WBuffer = MetalSystem.shared.device.makeBuffer(bytes: weights, length: weights.count * MemoryLayout<Float>.stride)!
        let W = MPSMatrix(buffer: WBuffer,
                          descriptor: MPSMatrixDescriptor(rows: samples.count,
                                                          columns: samples.count,
                                                          rowBytes: samples.count * 4,
                                                          dataType: .float32))
        
        let N = MPSMatrix(device: MetalSystem.shared.device,
                          descriptor: MPSMatrixDescriptor(rows: samples.count,
                                                          columns: controlPointCount,
                                                          rowBytes: controlPointCount * 4,
                                                          dataType: .float32))
        N.data.label = "N matrix"
        var edgeEquationCount = 0
        var equations: [[Float]] = []
        
        for j in 0..<vControlPointCount {
            var equation0: [Float] = .init(repeating: 0, count: controlPointCount)
            equation0[j * uControlPointCount] = 1
            equations.append(equation0)
            
            var equation1: [Float] = .init(repeating: 0, count: controlPointCount)
            equation1[j * uControlPointCount + uControlPointCount - 1] = 1
            equations.append(equation1)
            edgeEquationCount = edgeEquationCount + 2
        }
        
        for i in 1 ..< uControlPointCount - 1 {
            var equation0: [Float] = .init(repeating: 0, count: controlPointCount)
            equation0[i] = 1
            equations.append(equation0)
            
            var equation1: [Float] = .init(repeating: 0, count: controlPointCount)
            equation1[(vControlPointCount - 1) * uControlPointCount + i] = 1
            equations.append(equation1)
            
            edgeEquationCount = edgeEquationCount + 2
        }
        
        let MRows = innerIsoU.count * (vControlPointCount - 2) +
                    innerIsoV.count * (uControlPointCount - 2) +
                    edgeEquationCount
        
        for _ in edgeEquationCount..<MRows {
            equations.append(.init(repeating: 0, count: controlPointCount))
        }
        
        let MData = equations.flatMap { $0 }
        let MBuffer = MetalSystem.shared.device.makeBuffer(bytes: MData, length: MData.count * MemoryLayout<Float>.stride)!
        
        let M = MPSMatrix(buffer: MBuffer,
                          descriptor: MPSMatrixDescriptor(rows: MRows,
                                                          columns: controlPointCount,
                                                          rowBytes: controlPointCount * 4,
                                                          dataType: .float32))
        M.data.label = "M matrix"
        
        let SData = samples.map { [$0.1.x, $0.1.y, $0.1.z] }.flatMap { $0 }
        let SBuffer = MetalSystem.shared.device.makeBuffer(
            bytes: SData,
            length: SData.count * MemoryLayout<Float>.stride
        )!
        SBuffer.label = "S Buffer"
        let S = MPSMatrix(buffer: SBuffer,
                          descriptor: MPSMatrixDescriptor(rows: samples.count,
                                                          columns: 3,
                                                          rowBytes: 3 * 4,
                                                          dataType: .float32))
        
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = MetalSystem.shared.device
        
#if false
        do {
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            fatalError("error when trying to capture: \(error)")
        }
#endif
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            return .failure(MetalError.cannotMakeCommandBuffer)
        }
        
        let sampleUData = samples.map { $0.0.u }
        let sampleVDate = samples.map { $0.0.v }
        guard let sampleUBuffer = MetalSystem.shared.device.makeBuffer(
            bytes: sampleUData,
            length: MemoryLayout<Float>.stride * samples.count
        ) else { return .failure(MetalError.cannotMakeBuffer) }
        
        guard let sampleVBuffer = MetalSystem.shared.device.makeBuffer(
            bytes: sampleVDate,
            length: MemoryLayout<Float>.stride * samples.count
        ) else { return .failure(MetalError.cannotMakeBuffer) }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(MetalError.cannotMakeComputeCommandEncoder)
        }
        
        encoder.setComputePipelineState(Self.surfaceMatrixFillerState)
        encoder.setBytes([BSplineKernelArgument(degree: Int32(blendUBasis.degree),
                                                knotCount: Int32(blendUBasis.multiplicitySum))],
                         length: MemoryLayout<BSplineKernelArgument>.size,
                         index: 0)
        encoder.setBytes([BSplineKernelArgument(degree: Int32(blendVBasis.degree),
                                                knotCount: Int32(blendVBasis.multiplicitySum))],
                         length: MemoryLayout<BSplineKernelArgument>.size,
                         index: 1)
        encoder.setBuffer(blendUBasis.knotBuffer, offset: 0, index: 2)
        encoder.setBuffer(blendVBasis.knotBuffer, offset: 0, index: 3)
        encoder.setBytes([Int32(controlPointCount)],
                         length: MemoryLayout<Int32>.size,
                         index: 4)
        encoder.setBuffer(N.data, offset: 0, index: 5)
        encoder.setBuffer(sampleUBuffer, offset: 0, index: 6)
        encoder.setBuffer(sampleVBuffer, offset: 0, index: 7)
//        encoder.setBytes(samples.map { $0.0.x }, length: MemoryLayout<Float>.stride * samples.count, index: 6)
//        encoder.setBytes(samples.map { $0.0.y }, length: MemoryLayout<Float>.stride * samples.count, index: 7)
        encoder.dispatchThreadgroups(MTLSizeMake(samples.count, 1, 1),
                                     threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        
//        print("edgeEquationCount \(edgeEquationCount)")
        
        if !innerIsoV.isEmpty {
            encoder.setComputePipelineState(Self.uIsoCurveConstraintFiller)
            encoder.setBytes([BSplineKernelArgument(degree: Int32(blendUBasis.degree),
                                                    knotCount: Int32(blendUBasis.multiplicitySum))],
                             length: MemoryLayout<BSplineKernelArgument>.size,
                             index: 0)
            encoder.setBytes([BSplineKernelArgument(degree: Int32(blendVBasis.degree),
                                                    knotCount: Int32(blendVBasis.multiplicitySum))],
                             length: MemoryLayout<BSplineKernelArgument>.size,
                             index: 1)
            encoder.setBuffer(blendVBasis.knotBuffer, offset: 0, index: 2)
            encoder.setBytes([Int32(controlPointCount)], length: MemoryLayout<Int32>.size, index: 3)
            encoder.setBuffer(M.data,
                              offset: edgeEquationCount * M.rowBytes,
                              index: 4)
            encoder.setBytes(innerIsoV, length: MemoryLayout<Float>.stride * innerIsoV.count, index: 5)
            encoder.dispatchThreadgroups(MTLSizeMake(innerIsoV.count, uControlPointCount - 2, 1),
                                         threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        }
        
        if !innerIsoU.isEmpty {
            encoder.setComputePipelineState(Self.vIsoCurveConstraintFiller)
            encoder.setBytes([BSplineKernelArgument(degree: Int32(blendUBasis.degree),
                                                    knotCount: Int32(blendUBasis.multiplicitySum))],
                             length: MemoryLayout<BSplineKernelArgument>.size,
                             index: 0)
            encoder.setBytes([BSplineKernelArgument(degree: Int32(blendVBasis.degree),
                                                    knotCount: Int32(blendVBasis.multiplicitySum))],
                             length: MemoryLayout<BSplineKernelArgument>.size,
                             index: 1)
            encoder.setBuffer(blendUBasis.knotBuffer, offset: 0, index: 2)
            encoder.setBytes([Int32(controlPointCount)], length: MemoryLayout<Int32>.size, index: 3)
            encoder.setBuffer(M.data,
                              offset: (innerIsoV.count * (uControlPointCount - 2) + edgeEquationCount) * M.rowBytes,
                              index: 4)
            encoder.setBytes(innerIsoU, length: MemoryLayout<Float>.stride * innerIsoU.count, index: 5)
            encoder.dispatchThreadgroups(MTLSizeMake(innerIsoU.count, vControlPointCount - 2, 1),
                                         threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        }
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        guard let NtW = MatrixUtility.multiplicate(N, transposeLhs: true, W,
                                                   resultMatrixLabel: "NtW",
                                                   commandBufferLabel: "Multiply Nt & W") else {
            return .failure(PhantomError.unknown("Fail to multiply Nt and W"))
        }
        
        guard let NtWN = MatrixUtility.multiplicate(NtW, N,
                                                    resultMatrixLabel: "NtWN",
                                                    commandBufferLabel: "Multiply NtW & N") else {
            return .failure(PhantomError.unknown("Fail to multiply NtW and N"))
        }
        
        guard let NtWN_inversion = MatrixUtility.inverse(spdMatrix: NtWN,
                                                         resultMatrixLabel: "inversion of NtWN (referred to as NtWNi)",
                                                         commandBufferLabel: "Invert NtWN") else {
            return .failure(PhantomError.unknown("Fail to inverse NtWN"))
        }
        
        guard let Mi = MatrixUtility.multiplicate(M, NtWN_inversion, resultMatrixLabel: "Mi (M * NtWNi)", commandBufferLabel: "Multiply M & NtWNi") else {
            return .failure(PhantomError.unknown("Fail to multiply M & (NtWN)^-1"))
        }
        
        guard let MiMt = MatrixUtility.multiplicate(Mi, M, transposeRhs: true, resultMatrixLabel: "MiMt", commandBufferLabel: "Multiply Mi & Mt") else {
            return .failure(PhantomError.unknown("Fail to multiply Mi & Mt"))
        }
        
        guard let NtWS = MatrixUtility.multiplicate(NtW, S, resultMatrixLabel: "NtWS (Right Hand Side)", commandBufferLabel: "Multiply NtW & S") else {
            return .failure(PhantomError.unknown("Fail to multiply NtW and S"))
        }
        
        guard let MiNtWS = MatrixUtility.multiplicate(Mi, NtWS, resultMatrixLabel: "MiNtWS", commandBufferLabel: "Multiply Mi & NtWS") else {
            return .failure(PhantomError.unknown("Fail to multiply Mi & NtWS"))
        }
        
        // MiMt is not positive-definite
        guard let A = MatrixUtility.solve(matrix: MiMt, b: MiNtWS, resultMatrixLabel: "A (Lagrange Multipliers)", commandBufferLabel: "Solve A") else {
            return .failure(PhantomError.unknown("Fail to solve A"))
        }
        
        let rightHandSides = NtWS
        guard MatrixUtility.fma(alpha: -1, A: M, transposeA: true, B: A, beta: 1, C: rightHandSides, commandBufferLabel: "FMA") else {
            return .failure(PhantomError.unknown("Fail to compute right hand side"))
        }
        
        guard let NtWN2 = MatrixUtility.multiplicate(NtW, N,
                                                     resultMatrixLabel: "NtWN 2",
                                                     commandBufferLabel: "Multiply NtW & N 2") else {
            return .failure(PhantomError.unknown("Fail to multiply NtW and N 2"))
        }
        
        guard let P = MatrixUtility.solve(spdMatrix: NtWN2, b: rightHandSides,
                                          resultMatrixLabel: "P (Final Result)",
                                          commandBufferLabel: "Solve P") else {
            return .failure(PhantomError.unknown("Fail to solve P"))
        }
        
#if false
        captureManager.stopCapture()
#endif
        
//        print("Succeed P(\(P.rows), \(P.columns))")
        
        let pointer = P.data.contents()
        var controlNet: [[SIMD4<Float>]] = []
        var byteOffset: Int = 0
        for _ in 0..<vControlPointCount {
            var tempCPS: [SIMD4<Float>] = []
            for _ in 0..<uControlPointCount {
                let x = pointer.load(fromByteOffset: byteOffset, as: Float.self)
                let y = pointer.load(fromByteOffset: byteOffset + 4, as: Float.self)
                let z = pointer.load(fromByteOffset: byteOffset + 8, as: Float.self)
                byteOffset = byteOffset + 12
                tempCPS.append(.init(x: x, y: y, z: z, w: 1))
            }
            controlNet.append(tempCPS)
        }
        
        let modificationSurface = BSplineSurface(uKnots: blendUBasis.knots,
                                                 vKnots: blendVBasis.knots,
                                                 degrees: (blendUBasis.degree, blendVBasis.degree),
                                                 controlNet: controlNet)
        
        return .success(modificationSurface)
    }
    
    /// Guide a surface to target sample points with specified iso curves unchanged.
    ///
    /// ``isoU`` and ``isoV`` are the parameters where isocurves lie. These
    /// isocurves are fixed.
    ///
    /// - parameter originalSurface: the original surface (or basic surface) to be guided
    /// - parameter samples: the sample points to which the basic surface is going to be guided
    /// - parameter isoU: the _u_ values where the v-curves lie
    /// - parameter isoV: the _v_ values where the u-curves lie
    ///
    /// - throws: error when guidance fails
    ///
    /// - returns: a ``BSplineApproximator/GuidanceResult`` instance containing the desired surface
    static func guide(originalSurface surface: BSplineSurface,
                      samples: [(SIMD2<Float>, SIMD3<Float>)],
                      isoU: [Float] = [0, 1],
                      isoV: [Float] = [0, 1]
    ) throws -> GuidanceResult {
        let sampleDeviation: [(SIMD2<Float>, SIMD3<Float>)] = samples.map {
            ($0.0, $0.1 - surface.point(at: $0.0)!)
        }
        
        let result = generateDeviationSurface(uDegree: surface.uBasis.degree,
                                              vDegree: surface.vBasis.degree,
                                              sampleDeviation: sampleDeviation,
                                              isoU: isoU,
                                              isoV: isoV)

        switch result {
        case .success(let modificationSurface):
            let compatibleSurfaces = BSplineInterpolator.makeCompatible([modificationSurface, surface])
            
            var compatibleControlNet: [[SIMD4<Float>]] = compatibleSurfaces.last!.controlNet
            
            for i in 0..<compatibleControlNet.count {
                for j in 0..<compatibleControlNet[i].count {
                    compatibleControlNet[i][j] = compatibleControlNet[i][j] + compatibleSurfaces.first!.controlNet[i][j]
                }
            }
            
            let modifiedSurface = BSplineSurface(uBasis: compatibleSurfaces.first!.uBasis,
                                                 vBasis: compatibleSurfaces.first!.vBasis,
                                                 controlNet: compatibleControlNet,
                                                 controlPointColor: compatibleSurfaces.first!.controlPointColor)
            
            return GuidanceResult(originalSurface: surface,
                                  modifiedSurface: modifiedSurface,
                                  averageError: -1,
                                  maxError: -1)
        case .failure(let error):
            throw error
        }
    }
    
    /// Guides the given surface to the target curve.
    ///
    /// The parametric coordiates of the target curve samples are calculated via ``pcurve``,
    /// and the specified isocurves are fixed.
    ///
    /// - parameter surface: the original surface (or basic surface) to be guided
    /// - parameter pcurve: the 2D parametric curve for the target curve
    /// - parameter curve: the target curve to be guided to.
    /// - parameter sampleCount: the target curve sample count
    /// - parameter isoU: the _u_ values where the v-curves lie
    /// - parameter isoV: the _v_ values where the u-curves lie
    ///
    /// - throws: error when guidance fails
    ///
    /// - returns: a ``GuidanceResult`` instance containing the desired surface
    static func guide(originalSurface surface: BSplineSurface,
                      pcurve: BSplineCurve,
                      targetCurve curve: BSplineCurve,
                      sampleCount: Int = 100,
                      isoU: [Float] = [0, 1], //  u value
                      isoV: [Float] = [0, 1]) throws -> GuidanceResult {
        
        var curveSamples: [(SIMD2<Float>, SIMD3<Float>)] = []
        if sampleCount > 0 {
            for i in 1...sampleCount {
                let t = Float(i) / Float(sampleCount + 1)
                let parameterCoordinates = pcurve.point(at: t)

                let u = parameterCoordinates!.x
                let v = parameterCoordinates!.y

                if u < 0 || u > 1 || v < 0 || v > 1 { continue }

                let spatialPosition = curve.point(at: t)!
                curveSamples.append(([u, v], spatialPosition))
            }
        }
        
        return try guide(originalSurface: surface, samples: curveSamples, isoU: isoU, isoV: isoV)
    }
    
    /// Compute new knots based on error set. The new knots should decrease the error when used for surface fitting
    ///
    /// - Parameters:
    ///   - currentErrorSet: current error set, each item of which consists of a _(u,v)_ and a `Float` representing the corresponding error
    ///   - currentMaxErrorItem: the item whose error is the maximum within `currentErrorSet`
    ///   - tolerance: tolerance
    ///   - blendUKnots: current _U_ knot vector
    ///   - blendVKnots: current _V_ knot vector
    /// - Returns: A tuple, with the first element being the knot span indices _(i,j)_ and the second element being the computed new knots _(u,v)_
    static func computeNewKnots(
        currentErrorSet: [(SIMD2<Float>, Float)],
        currentMaxErrorItem: (SIMD2<Float>, Float),
        tolerance: Float,
        blendUKnots: [BSplineBasis.Knot],
        blendVKnots: [BSplineBasis.Knot]
    ) -> (SIMD2<Int>, SIMD2<Float>) {
        let maxUV = currentMaxErrorItem.0
        let maxI = max(blendUKnots.firstIndex { $0.value >= maxUV.x }! - 1, 0)
        let maxJ = max(blendVKnots.firstIndex { $0.value >= maxUV.y }! - 1, 0)
        
        let startU = blendUKnots[maxI].value
        let endU = blendUKnots[maxI + 1].value
        let midU = (startU + endU) / 2
        
        let startV = blendVKnots[maxJ].value
        let endV = blendVKnots[maxJ + 1].value
        let midV = (startV + endV) / 2
        
        let currentExceptionSet = currentErrorSet.filter { (uv, error) in
            let u = uv.x
            let v = uv.y
            let e = error
            return e > tolerance && startU <= u && u <= endU && startV <= v && v <= endV
        }
        
        var weightedAveragePos: SIMD2<Float> = .zero
        var errorSum: Float = 0
        currentExceptionSet.forEach { errorSum += $0.1 }
        
        currentExceptionSet.forEach { (uv, error) in
            let weight = error / errorSum
            weightedAveragePos += weight * uv
        }
        
        let uKnot = (weightedAveragePos.x + midU) / 2
        let vKnot = (weightedAveragePos.y + midV) / 2
        
        return (.init(maxI, maxJ), .init(uKnot, vKnot))
        
//        blendUKnots.insert(.init(value: uKnot, multiplicity: 1), at: maxI + 1)
//        blendVKnots.insert(.init(value: vKnot, multiplicity: 1), at: maxJ + 1)
    }
    
    /// Guides the given surface to the target curve with the error controlled.
    ///
    /// The error control type is _Type1_, which starts from few knots and insert more knots.
    ///
    /// - parameter originalSurface: the original surface (or basic surface) to be guided
    /// - parameter samples: the sample points to which the basic surface is going to be guided
    /// - parameter isoU: the _u_ values where the v-curves lie
    /// - parameter isoV: the _v_ values where the u-curves lie
    /// - parameter tolerance: the tolerance within which the error will be narrowed
    ///
    /// - returns: a ``BSplineApproximator/GuidanceResult`` instance containing the desired surface, wrapped by ``Result``
    static func guideWithErrorControlType1EvenBatch(
        originalSurface: BSplineSurface,
        samples: [(SIMD2<Float>, SIMD3<Float>)],
        isoU: [Float] = [0, 1],
        isoV: [Float] = [0, 1],
        tolerance: Float = 0.1
    ) -> Result<GuidanceResult, Error> {
        let surface = originalSurface
        let sampleDeviation: [(SIMD2<Float>, SIMD3<Float>)] = samples.map { (uv, xyz) in
            (uv, xyz - surface.point(at: uv)!)
        }
        
        let sampleError: [Float] = sampleDeviation.map { length($0.1) }
        guard let maxError = sampleError.max() else {
            return .failure(PhantomError.unknown("No sample specified."))
        }
        
        if maxError < tolerance {
            return .success(GuidanceResult(originalSurface: originalSurface,
                                           modifiedSurface: originalSurface,
                                           averageError: -1,
                                           maxError: maxError))
        }
        
        let p = originalSurface.uBasis.degree
        let q = originalSurface.vBasis.degree
        
        var currentMaxError = maxError
        let innerIsoU = Array(isoU[isoU.startIndex + 1 ..< isoU.endIndex - 1])
        let innerIsoV = Array(isoV[isoV.startIndex + 1 ..< isoV.endIndex - 1])
        
        var blendUKnots = biconstrainedKnots(for: isoU, degree: p)
        var blendVKnots = biconstrainedKnots(for: isoV, degree: q)
        
        let uKnots = blendUKnots
        let vKnots = blendVKnots
        
        /// number of knots to be inserted in each span
        var uSpansInsertion: [Int] = .init(repeating: 0, count: uKnots.count - 1)
        var vSpansInsertion: [Int] = .init(repeating: 0, count: vKnots.count - 1)
        
        var currentDeviationSurface: BSplineSurface? = nil
        var iterationCount: Int = 0
        
        while currentMaxError > tolerance {
            iterationCount += 1
            
            let blendUBasis = BSplineBasis(degree: p, knots: blendUKnots)
            let blendVBasis = BSplineBasis(degree: q, knots: blendVKnots)
            let devResult = generateDeviationSurface(blendUBasis: blendUBasis,
                                                     blendVBasis: blendVBasis,
                                                     sampleDeviation: sampleDeviation,
                                                     innerIsoU: innerIsoU,
                                                     innerIsoV: innerIsoV)
            
            switch devResult {
            case .success(let ds):
                let currentSampleDeviation = sampleDeviation.map { (uv, dxyz) in (uv, dxyz - ds.point(at: uv)!) }
                let currentSampleError = currentSampleDeviation.map { (uv, dxyz) in (uv, length(dxyz)) }
                let currentMaxErrorItem = currentSampleError.max { $0.1 < $1.1 }!
                currentMaxError = currentMaxErrorItem.1
                
                print("max error: \(currentMaxError) at iteration \(iterationCount)")
                
                if currentMaxError > tolerance {let currentExceptionalSamples = currentSampleError.filter { $0.1 > tolerance }
                    
                    currentExceptionalSamples.forEach { (uv, _) in
                        let u = uv.u
                        let v = uv.v
                        
                        let i = uKnots.firstIndex { $0.value >= u }! - 1
                        let j = vKnots.firstIndex { $0.value >= v }! - 1
                        
                        uSpansInsertion[i] += 1
                        vSpansInsertion[j] += 1
                    }
                    
                    blendUKnots = uKnots
                    blendVKnots = vKnots
                    
                    for i in (0..<uSpansInsertion.count).reversed() {
                        let start = blendUKnots[i].value
                        let end = blendUKnots[i + 1].value
                        
                        let count = uSpansInsertion[i]
                        if count <= 0 { continue }
                        
                        let knots = Float.sample(in: start ..< end, count: count, inclusive: false)
                            .map { BSplineBasis.Knot(value: $0, multiplicity: 1) }
                        
                        blendUKnots.insert(contentsOf: knots, at: i + 1)
                    }
                    
                    for j in (0..<vSpansInsertion.count).reversed() {
                        let start = blendVKnots[j].value
                        let end = blendVKnots[j + 1].value
                        
                        let count = vSpansInsertion[j]
                        if count <= 0 { continue }
                        
                        let knots = Float.sample(in: start ..< end, count: count, inclusive: false)
                            .map { BSplineBasis.Knot(value: $0, multiplicity: 1) }
                        
                        blendVKnots.insert(contentsOf: knots, at: j + 1)
                    }
                } else {
                    currentDeviationSurface = ds
                }
            case .failure(let error):
                return .failure(error)
            }
        }
        
        guard let currentDeviationSurface else { return .failure(PhantomError.unknown("Deviation surface is not generated.")) }
        let compatibleSurfaces = BSplineInterpolator.makeCompatible([currentDeviationSurface, surface])
        
        var compatibleControlNet: [[SIMD4<Float>]] = compatibleSurfaces.last!.controlNet
        
        for i in 0..<compatibleControlNet.count {
            for j in 0..<compatibleControlNet[i].count {
                compatibleControlNet[i][j] = compatibleControlNet[i][j] + compatibleSurfaces.first!.controlNet[i][j]
            }
        }
        
        let modifiedSurface = BSplineSurface(uBasis: compatibleSurfaces.first!.uBasis,
                                             vBasis: compatibleSurfaces.first!.vBasis,
                                             controlNet: compatibleControlNet,
                                             controlPointColor: compatibleSurfaces.first!.controlPointColor)
        
        print("Type1 error control succeeded, \(iterationCount) iterations passed")
        return .success(.init(originalSurface: originalSurface,
                              modifiedSurface: modifiedSurface,
                              averageError: -1,
                              maxError: currentMaxError))
    }
    
    /// Guides the given surface to the target curve with the error controlled.
    ///
    /// The error control type is _Type1_, which starts from few knots and insert more knots.
    /// The insertion strategy is refined. __Determine a single (u,v) by error-weighted averaged parametric coordinates__
    ///
    /// - parameter originalSurface: the original surface (or basic surface) to be guided
    /// - parameter samples: the sample points to which the basic surface is going to be guided
    /// - parameter isoU: the _u_ values where the v-curves lie
    /// - parameter isoV: the _v_ values where the u-curves lie
    /// - parameter tolerance: the tolerance within which the error will be narrowed
    ///
    /// - returns: a ``BSplineApproximator/GuidanceResult`` instance containing the desired surface, wrapped by ``Result``
    static func guideWithErrorControlType1RefinedSingle(
        originalSurface: BSplineSurface,
        samples: [(SIMD2<Float>, SIMD3<Float>)],
        isoU: [Float] = [0, 1],
        isoV: [Float] = [0, 1],
        tolerance: Float = 0.1
    ) -> Result<GuidanceResult, Error> {
        let surface = originalSurface
        let sampleDeviation: [(SIMD2<Float>, SIMD3<Float>)] = samples.map { (uv, xyz) in
            (uv, xyz - surface.point(at: uv)!)
        }
        
        let sampleError: [Float] = sampleDeviation.map { length($0.1) }
        guard let maxError = sampleError.max() else {
            return .failure(PhantomError.unknown("No sample specified."))
        }
        
        if maxError < tolerance {
            return .success(GuidanceResult(originalSurface: originalSurface,
                                           modifiedSurface: originalSurface,
                                           averageError: -1,
                                           maxError: maxError))
        }
        
        let p = originalSurface.uBasis.degree
        let q = originalSurface.vBasis.degree
        
        var currentMaxError = maxError
        
        let innerIsoU = Array(isoU[isoU.startIndex + 1 ..< isoU.endIndex - 1])
        let innerIsoV = Array(isoV[isoV.startIndex + 1 ..< isoV.endIndex - 1])
        
        var blendUKnots = biconstrainedKnots(for: isoU, degree: p)
        var blendVKnots = biconstrainedKnots(for: isoV, degree: q)
        
        var currentDeviationSurface: BSplineSurface? = nil
        var iterationCount: Int = 0
        
        while currentMaxError > tolerance {
            iterationCount += 1
            
            let blendUBasis = BSplineBasis(degree: p, knots: blendUKnots)
            let blendVBasis = BSplineBasis(degree: q, knots: blendVKnots)
            let devResult = generateDeviationSurface(blendUBasis: blendUBasis,
                                                     blendVBasis: blendVBasis,
                                                     sampleDeviation: sampleDeviation,
                                                     innerIsoU: innerIsoU,
                                                     innerIsoV: innerIsoV)
            
            switch devResult {
            case .success(let ds):
                let currentSampleDeviation = sampleDeviation.map { (uv, dxyz) in (uv, dxyz - ds.point(at: uv)!) }
                let currentSampleError = currentSampleDeviation.map { (uv, dxyz) in (uv, length(dxyz)) }
                let currentMaxErrorItem = currentSampleError.max { $0.1 < $1.1 }!
                currentMaxError = currentMaxErrorItem.1
                
                print("max error: \(currentMaxError) at iteration \(iterationCount)")
                
                if currentMaxError > tolerance {
                    let maxErrorU = currentMaxErrorItem.0.u
                    let maxErrorV = currentMaxErrorItem.0.v
                    
                    let maxErrorI = blendUKnots.firstIndex { $0.value >= maxErrorU }! - 1
                    let maxErrorJ = blendVKnots.firstIndex { $0.value >= maxErrorV }! - 1
                    
                    let startU = blendUKnots[maxErrorI].value
                    let endU = blendUKnots[maxErrorI + 1].value
                    let midU = (startU + endU) / 2
                    
                    let startV = blendVKnots[maxErrorJ].value
                    let endV = blendVKnots[maxErrorJ + 1].value
                    let midV = (startV + endV) / 2
                    
                    let currentExceptionalSamples = currentSampleError.filter { (uv, e) in
                        let u = uv.u
                        let v = uv.v
                        return e > tolerance && startU <= u && u <= endU && startV <= v && v <= endV
                    }
                
                    let errorSum: Float = currentExceptionalSamples.reduce(into: 0) { result, item in
                        result += item.1
                    }
                    
                    let weightedAveragePos: SIMD2<Float> = currentExceptionalSamples.reduce(into: .zero) { result, item in
                        let uv = item.0
                        let error = item.1
                        let weight = error / errorSum
                        result += weight * uv
                    }
                    
                    // prevent approaching span ends
                    let uKnot = (weightedAveragePos.u + midU) / 2
                    let vKnot = (weightedAveragePos.v + midV) / 2
                    
                    blendUKnots.insert(.init(value: uKnot, multiplicity: 1), at: maxErrorI + 1)
                    blendVKnots.insert(.init(value: vKnot, multiplicity: 1), at: maxErrorJ + 1)
                } else {
                    currentDeviationSurface = ds
                }
            case .failure(let error):
                return .failure(error)
            }
        }
        guard let currentDeviationSurface else { return .failure(PhantomError.unknown("Deviation surface is not generated.")) }
        let compatibleSurfaces = BSplineInterpolator.makeCompatible([currentDeviationSurface, surface])
        
        var compatibleControlNet: [[SIMD4<Float>]] = compatibleSurfaces.last!.controlNet
        
        for i in 0..<compatibleControlNet.count {
            for j in 0..<compatibleControlNet[i].count {
                compatibleControlNet[i][j] = compatibleControlNet[i][j] + compatibleSurfaces.first!.controlNet[i][j]
            }
        }
        
        let modifiedSurface = BSplineSurface(uBasis: compatibleSurfaces.first!.uBasis,
                                             vBasis: compatibleSurfaces.first!.vBasis,
                                             controlNet: compatibleControlNet,
                                             controlPointColor: compatibleSurfaces.first!.controlPointColor)
        
        print("Type1 error control succeeded, \(iterationCount) iterations passed")
        return .success(.init(originalSurface: originalSurface,
                              modifiedSurface: modifiedSurface,
                              averageError: -1,
                              maxError: currentMaxError))
    }
    
    /// Guides the given surface to the target curve with the error controlled.
    ///
    /// The error control type is _Type1_, which starts from few knots and insert more knots.
    /// The insertion strategy is refined.
    ///
    /// - parameter originalSurface: the original surface (or basic surface) to be guided
    /// - parameter samples: the sample points to which the basic surface is going to be guided
    /// - parameter isoU: the _u_ values where the v-curves lie
    /// - parameter isoV: the _v_ values where the u-curves lie
    /// - parameter tolerance: the tolerance within which the error will be narrowed
    ///
    /// - returns: a ``BSplineApproximator/GuidanceResult`` instance containing the desired surface, wrapped by ``Result``
    static func guideWithErrorControlType1RefinedBatch(
        originalSurface: BSplineSurface,
        samples: [(SIMD2<Float>, SIMD3<Float>)],
        isoU: [Float] = [0, 1],
        isoV: [Float] = [0, 1],
        tolerance: Float = 0.1
    ) -> Result<GuidanceResult, Error> {
        let surface = originalSurface
        let sampleDeviation: [(SIMD2<Float>, SIMD3<Float>)] = samples.map { (uv, xyz) in
            (uv, xyz - surface.point(at: uv)!)
        }
        
        let sampleError: [Float] = sampleDeviation.map { length($0.1) }
        guard let maxError = sampleError.max() else {
            return .failure(PhantomError.unknown("No sample specified."))
        }
        
        if maxError < tolerance {
            return .success(GuidanceResult(originalSurface: originalSurface,
                                           modifiedSurface: originalSurface,
                                           averageError: -1,
                                           maxError: maxError))
        }
        
        let p = originalSurface.uBasis.degree
        let q = originalSurface.vBasis.degree
        
        var currentMaxError = maxError
        
        let innerIsoU = Array(isoU[isoU.startIndex + 1 ..< isoU.endIndex - 1])
        let innerIsoV = Array(isoV[isoV.startIndex + 1 ..< isoV.endIndex - 1])
        
        var blendUKnots = biconstrainedKnots(for: isoU, degree: p)
        var blendVKnots = biconstrainedKnots(for: isoV, degree: q)
        
        var currentDeviationSurface: BSplineSurface? = nil
        var iterationCount: Int = 0
        
        while currentMaxError > tolerance {
            iterationCount += 1
            
            let blendUBasis = BSplineBasis(degree: p, knots: blendUKnots)
            let blendVBasis = BSplineBasis(degree: q, knots: blendVKnots)
            let devResult = generateDeviationSurface(blendUBasis: blendUBasis,
                                                     blendVBasis: blendVBasis,
                                                     sampleDeviation: sampleDeviation,
                                                     innerIsoU: innerIsoU,
                                                     innerIsoV: innerIsoV)
            
            switch devResult {
            case .success(let ds):
                let currentSampleDeviation = sampleDeviation.map { (uv, dxyz) in (uv, dxyz - ds.point(at: uv)!) }
                let currentSampleError = currentSampleDeviation.map { (uv, dxyz) in (uv, length(dxyz)) }
                let currentMaxErrorItem = currentSampleError.max { $0.1 < $1.1 }!
                currentMaxError = currentMaxErrorItem.1
                
                print("max error: \(currentMaxError) at iteration \(iterationCount)")
                
                if currentMaxError > tolerance {
                    let currentExceptionalSamples = currentSampleError.filter { $0.1 > tolerance }
                    
                    let currentUSpanCount = blendUKnots.count - 1
                    let currentVSpanCount = blendVKnots.count - 1
                    
                    /// (u, error)
                    var uSpansSamples: [[(Float, Float)]] = .init(repeating: [], count: currentUSpanCount)
                    var vSpansSamples: [[(Float, Float)]] = .init(repeating: [], count: currentVSpanCount)
                    
                    currentExceptionalSamples.forEach { (uv, error) in
                        let u = uv.u
                        let v = uv.v
                        
                        let i = blendUKnots.firstIndex { $0.value >= u }! - 1
                        let j = blendVKnots.firstIndex { $0.value >= v }! - 1
                        
                        uSpansSamples[i].append((u, error))
                        vSpansSamples[j].append((v, error))
                    }
                    
                    uSpansSamples.enumerated().reversed().forEach { (i, samples) in
                        guard !samples.isEmpty else { return }
                        
                        let start = blendUKnots[i].value
                        let end = blendUKnots[i + 1].value
                        let mid = (start + end) / 2
                        
                        var weightedAverageU: Float = 0
                        var errorSum: Float = 0
                        
                        samples.forEach { (u, error) in
                            weightedAverageU += error * u
                            errorSum += error
                        }
                        
                        weightedAverageU /= errorSum
                        
                        let uKnot = (weightedAverageU + mid) / 2
                        
                        blendUKnots.insert(.init(value: uKnot, multiplicity: 1), at: i + 1)
                    }
                    
                    vSpansSamples.enumerated().reversed().forEach { (j, samples) in
                        guard !samples.isEmpty else { return }
                        
                        let start = blendVKnots[j].value
                        let end = blendVKnots[j + 1].value
                        let mid = (start + end) / 2
                        
                        var weightedAverageV: Float = 0
                        var errorSum: Float = 0
                        samples.forEach { (v, error) in
                            weightedAverageV += error * v
                            errorSum += error
                        }
                        
                        weightedAverageV /= errorSum
                        
                        let vKnot = (weightedAverageV + mid) / 2
                        
                        blendVKnots.insert(.init(value: vKnot, multiplicity: 1), at: j + 1)
                    }
                } else {
                    currentDeviationSurface = ds
                }
            case .failure(let error):
                return .failure(error)
            }
        }
        guard let currentDeviationSurface else { return .failure(PhantomError.unknown("Deviation surface is not generated.")) }
        let compatibleSurfaces = BSplineInterpolator.makeCompatible([currentDeviationSurface, surface])
        
        var compatibleControlNet: [[SIMD4<Float>]] = compatibleSurfaces.last!.controlNet
        
        for i in 0..<compatibleControlNet.count {
            for j in 0..<compatibleControlNet[i].count {
                compatibleControlNet[i][j] = compatibleControlNet[i][j] + compatibleSurfaces.first!.controlNet[i][j]
            }
        }
        
        let modifiedSurface = BSplineSurface(uBasis: compatibleSurfaces.first!.uBasis,
                                             vBasis: compatibleSurfaces.first!.vBasis,
                                             controlNet: compatibleControlNet,
                                             controlPointColor: compatibleSurfaces.first!.controlPointColor)
        
        print("Type1 error control succeeded, \(iterationCount) iterations passed")
        return .success(.init(originalSurface: originalSurface,
                              modifiedSurface: modifiedSurface,
                              averageError: -1,
                              maxError: currentMaxError))
    }
    
    /// Guides the given surface to the target curve with the error controlled.
    ///
    /// The error control type is _Type1_, which starts from few knots and insert more knots.
    /// The insertion strategy is naive.
    ///
    /// - parameter originalSurface: the original surface (or basic surface) to be guided
    /// - parameter samples: the sample points to which the basic surface is going to be guided
    /// - parameter isoU: the _u_ values where the v-curves lie
    /// - parameter isoV: the _v_ values where the u-curves lie
    /// - parameter tolerance: the tolerance within which the error will be narrowed
    ///
    /// - returns: a ``BSplineApproximator/GuidanceResult`` instance containing the desired surface, wrapped by ``Result``
    static func guideWithErrorControlType1RefinedMax(
        originalSurface: BSplineSurface,
        samples: [(SIMD2<Float>, SIMD3<Float>)],
        isoU: [Float] = [0, 1],
        isoV: [Float] = [0, 1],
        tolerance: Float = 0.1
    ) -> Result<GuidanceResult, Error> {
        let surface = originalSurface
        let sampleDeviation: [(SIMD2<Float>, SIMD3<Float>)] = samples.map { (uv, xyz) in
            (uv, xyz - surface.point(at: uv)!)
        }
        
        let sampleError: [Float] = sampleDeviation.map { length($0.1) }
        guard let maxError = sampleError.max() else {
            return .failure(PhantomError.unknown("No sample specified."))
        }
        
        if maxError < tolerance {
            return .success(GuidanceResult(originalSurface: originalSurface,
                                           modifiedSurface: originalSurface,
                                           averageError: -1,
                                           maxError: maxError))
        }
        
        let p = originalSurface.uBasis.degree
        let q = originalSurface.vBasis.degree
        
        var currentMaxError = maxError
        
        let innerIsoU = Array(isoU[isoU.startIndex + 1 ..< isoU.endIndex - 1])
        let innerIsoV = Array(isoV[isoV.startIndex + 1 ..< isoV.endIndex - 1])
        
        var blendUKnots = biconstrainedKnots(for: isoU, degree: p)
        var blendVKnots = biconstrainedKnots(for: isoV, degree: q)
        
        var currentDeviationSurface: BSplineSurface? = nil
        var iterationCount: Int = 0
        
        var maxErrorSequence = [currentMaxError]
        var uKnotsSequence = [(iteration: 0, knots: blendUKnots)]
        var vKnotsSequence = [(iteration: 0, knots: blendVKnots)]
        let startTime = Date.now
        var timeSequence = [startTime]
        
        while currentMaxError > tolerance {
            iterationCount += 1
            
            let blendUBasis = BSplineBasis(degree: p, knots: blendUKnots)
            let blendVBasis = BSplineBasis(degree: q, knots: blendVKnots)
            let devResult = generateDeviationSurface(blendUBasis: blendUBasis,
                                                     blendVBasis: blendVBasis,
                                                     sampleDeviation: sampleDeviation,
                                                     innerIsoU: innerIsoU,
                                                     innerIsoV: innerIsoV)
            
            switch devResult {
            case .success(let ds):
                let currentSampleDeviation = sampleDeviation.map { (uv, dxyz) in (uv, dxyz - ds.point(at: uv)!) }
                let currentSampleError = currentSampleDeviation.map { (uv, dxyz) in (uv, length(dxyz)) }
                let currentMaxErrorItem = currentSampleError.max { $0.1 < $1.1 }!
                currentMaxError = currentMaxErrorItem.1
                
                print("max error: \(currentMaxError) at iteration \(iterationCount)")
                maxErrorSequence.append(currentMaxError)
                timeSequence.append(.now)
                
                if currentMaxError > tolerance {
                    let u = currentMaxErrorItem.0.u
                    let v = currentMaxErrorItem.0.v
                    
                    let i = blendUKnots.firstIndex { $0.value >= u }!
                    let j = blendVKnots.firstIndex { $0.value >= v }!
                    
                    let midU = (blendUKnots[i].value + blendUKnots[i - 1].value) / 2
                    let midV = (blendVKnots[j].value + blendVKnots[j - 1].value) / 2
                    
                    let knotU = (midU + u) / 2
                    let knotV = (midV + v) / 2
                    
                    blendUKnots.insert(.init(value: knotU, multiplicity: 1), at: i)
                    blendVKnots.insert(.init(value: knotV, multiplicity: 1), at: j)
                    
                    uKnotsSequence.append((iteration: iterationCount, knots: blendUKnots))
                    vKnotsSequence.append((iteration: iterationCount, knots: blendVKnots))
                } else {
                    currentDeviationSurface = ds
                }
            case .failure(let error):
                return .failure(error)
            }
        }
        
        guard let currentDeviationSurface else { return .failure(PhantomError.unknown("Deviation surface is not generated.")) }
        let compatibleSurfaces = BSplineInterpolator.makeCompatible([currentDeviationSurface, surface])
        
        var compatibleControlNet: [[SIMD4<Float>]] = compatibleSurfaces.last!.controlNet
        
        for i in 0..<compatibleControlNet.count {
            for j in 0..<compatibleControlNet[i].count {
                compatibleControlNet[i][j] = compatibleControlNet[i][j] + compatibleSurfaces.first!.controlNet[i][j]
            }
        }
        
        let modifiedSurface = BSplineSurface(uBasis: compatibleSurfaces.first!.uBasis,
                                             vBasis: compatibleSurfaces.first!.vBasis,
                                             controlNet: compatibleControlNet,
                                             controlPointColor: compatibleSurfaces.first!.controlPointColor)
        
        print("Type1 error control succeeded, \(iterationCount) iterations passed")
        print("---- type1 gradual (max) fitting ended ----")
        print(maxErrorSequence)
        print("U")
        print(uKnotsSequence)
        print("V")
        print(vKnotsSequence)
        print("Time")
        print(timeSequence.map { $0.timeIntervalSince(startTime) })
        
        return .success(.init(originalSurface: originalSurface,
                              modifiedSurface: modifiedSurface,
                              averageError: -1,
                              maxError: currentMaxError))
    }
    
    /// Guides the given surface to the target curve with the error controlled.
    ///
    /// The error control type is ours, which combines error control _Type1_ and parametric correction.
    ///
    /// - parameter originalSurface: the original surface (or basic surface) to be guided
    /// - parameter samples: the sample points to which the basic surface is going to be guided
    /// - parameter isoU: the _u_ values where the v-curves lie
    /// - parameter isoV: the _v_ values where the u-curves lie
    /// - parameter tolerance: the tolerance within which the error will be narrowed
    ///
    /// - returns: a ``Phantom/BSplineApproximator/GuidanceResult`` instance containing the desired surface, wrapped by ``Result``
    static func guideWithOurErrorControl(
        originalSurface: BSplineSurface,
        samples: [(SIMD2<Float>, SIMD3<Float>)],
        isoU: [Float] = [0, 1],
        isoV: [Float] = [0, 1],
        tolerance: Float = 0.1
    ) -> Result<GuidanceResult, Error> {
        if samples.isEmpty { return .failure(PhantomError.unknown("no samples specified")) }
        
        var surface = originalSurface
        
        var currentSamples = samples
        
        var sampleDeviation = currentSamples.map { ($0.0, $0.1 - surface.point(at: $0.0)!) }
        var errorSet = sampleDeviation.map { ($0.0, length($0.1)) }
        var maxErrorItem = errorSet.max { $0.1 < $1.1 }!
        var maxError = maxErrorItem.1
        
        var surfaceSequence = [surface]
        var maxErrorSequence = [maxError]
        var minMaxErrorIndex = 0
        
        if maxError <= tolerance {
            return .success(.init(originalSurface: originalSurface,
                                  modifiedSurface: originalSurface,
                                  averageError: -1,
                                  maxError: maxError))
        }
        
        let p = originalSurface.uBasis.degree
        let q = originalSurface.vBasis.degree
        
        let innerIsoU = Array(isoU[isoU.startIndex + 1 ..< isoU.endIndex - 1])
        let innerIsoV = Array(isoV[isoV.startIndex + 1 ..< isoV.endIndex - 1])
        
        var blendUKnots = biconstrainedKnots(for: isoU, degree: p)
        var blendVKnots = biconstrainedKnots(for: isoV, degree: q)
        
        var iterationNumber = 0
        var moment: Float? = nil
        let momentRatioOfChange: Float = 0.5
        
        var uKnotsSequence = [(iteration: 0, knots: blendUKnots)]
        var vKnotsSequence = [(iteration: 0, knots: blendVKnots)]
        let startTime = Date.now
        var timeSequence = [startTime]
        
        repeat {
            iterationNumber += 1
            // TODO: iterate
            /// その自分を忘れて下さい
            let blendUBasis = BSplineBasis(degree: p, knots: blendUKnots)
            let blendVBasis = BSplineBasis(degree: q, knots: blendVKnots)
            let devResult = generateDeviationSurface(blendUBasis: blendUBasis,
                                                     blendVBasis: blendVBasis,
                                                     sampleDeviation: sampleDeviation,
                                                     innerIsoU: innerIsoU,
                                                     innerIsoV: innerIsoV)
            
            var incompatibleSurfaces: [BSplineSurface] = []
            
            switch devResult {
            case .success(let deviationSurface):
                incompatibleSurfaces = [deviationSurface, surface]
            case .failure(let error):
                return .failure(error)
            }

            let compatibleSurfaces = BSplineInterpolator.makeCompatible(incompatibleSurfaces)
            var compatibleControlNet: [[SIMD4<Float>]] = compatibleSurfaces.last!.controlNet
            
            for i in 0..<compatibleControlNet.count {
                for j in 0..<compatibleControlNet[i].count {
                    compatibleControlNet[i][j] = compatibleControlNet[i][j] + compatibleSurfaces.first!.controlNet[i][j]
                }
            }
            
            let modifiedSurface = BSplineSurface(uBasis: compatibleSurfaces.first!.uBasis,
                                                 vBasis: compatibleSurfaces.first!.vBasis,
                                                 controlNet: compatibleControlNet,
                                                 controlPointColor: compatibleSurfaces.first!.controlPointColor)
            
            // [(uv, xyz)]
//            let startValueCandidates = surface.generateStartValueCandidates()
            currentSamples = currentSamples.map { (uv, xyz) in
                let modifiedUV = modifiedSurface.inverse(
                    xyz,
                    uv0: uv,
                    e1: 1e-6,
                    e2: 1e-6,
                    maxIteration: 50
                )
                
                return (modifiedUV, xyz)
            }
            
            let currentSampleDeviation = currentSamples.map { (uv, xyz) in (uv, xyz - modifiedSurface.point(at: uv)!) }
            let currentErrorSet = currentSampleDeviation.map { (uv, dxyz) in (uv, length(dxyz)) }
            let currentMaxErrorItem = currentErrorSet.max { $0.1 < $1.1 }!
            let currentMaxError = currentMaxErrorItem.1
            
            print("i: \(iterationNumber) & e = \(currentMaxError)")
            
            timeSequence.append(.now)
            
            if currentMaxError < tolerance {
                print("---- our method fitting ended ----")
                print(maxErrorSequence)
                print("U")
                print(uKnotsSequence)
                print("V")
                print(vKnotsSequence)
                print("Time")
                print(timeSequence.map { $0.timeIntervalSince(startTime) })
                return .success(.init(originalSurface: originalSurface,
                                      modifiedSurface: modifiedSurface,
                                      averageError: -1,
                                      maxError: currentMaxError))
            }
            
            /// check if knot insertion is necessary by evaluating delta error
            let delta = maxError - currentMaxError
            
            sampleDeviation = currentSampleDeviation
            errorSet = currentErrorSet
            maxErrorItem = currentMaxErrorItem
            maxError = currentMaxError
            surface = modifiedSurface
            
            surfaceSequence.append(surface)
            maxErrorSequence.append(maxError)
            
            if maxErrorSequence[minMaxErrorIndex] < maxError {
                minMaxErrorIndex = iterationNumber
            }
            
            if let lastMoment = moment {
                moment = (1 - momentRatioOfChange) * lastMoment + momentRatioOfChange * delta
            } else {
                moment = delta
            }
            
            let distance = maxError - tolerance
            let estimatedFutureStepCount = distance / moment!
            
            // estimated to converge in <threshold> steps
            let threshold: Float = 10
            if estimatedFutureStepCount > threshold || delta < 0 {
                /// insert knot
                let newKnots = computeNewKnots(
                    currentErrorSet: currentErrorSet,
                    currentMaxErrorItem: currentMaxErrorItem,
                    tolerance: tolerance,
                    blendUKnots: blendUKnots,
                    blendVKnots: blendVKnots
                )
                
                let maxI = newKnots.0.x
                let maxJ = newKnots.0.y
                
                let uKnot = newKnots.1.u
                let vKnot = newKnots.1.v
                
                blendUKnots.insert(.init(value: uKnot, multiplicity: 1), at: maxI + 1)
                blendVKnots.insert(.init(value: vKnot, multiplicity: 1), at: maxJ + 1)
                
                uKnotsSequence.append((iteration: iterationNumber, knots: blendUKnots))
                vKnotsSequence.append((iteration: iterationNumber, knots: blendVKnots))
            }
        } while maxError > tolerance
        
        return .failure(PhantomError.unknown("MOCK"))
    }
    
    /// Approximate given sample points with a surface.
    ///
    /// The bases of the surface is specified.
    ///
    /// - parameter samples: the sample points to be fitted, consisting of a parametric coordinate _(u,v)_ and a spatial position _(x,y,z)_
    /// - parameter uBasis: the _u_ basis for the surface
    /// - parameter vBasis: the _v_ basis for the surface
    ///
    /// - throws: error when approximation fails
    ///
    /// - returns: the desired ``BSplineSurface`` instance
    static func approximate(samples: [(SIMD2<Float>, SIMD3<Float>)],
                            uBasis: BSplineBasis,
                            vBasis: BSplineBasis) throws -> BSplineSurface {
        
        let uControlPointCount = uBasis.multiplicitySum - uBasis.order
        let vControlPointCount = vBasis.multiplicitySum - vBasis.order
        
        let controlPointCount = uControlPointCount * vControlPointCount
        
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = MetalSystem.shared.device
        
#if false
        do {
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            fatalError("error when trying to capture: \(error)")
        }
#endif
        
        let N = MPSMatrix(device: MetalSystem.shared.device,
                          descriptor: MPSMatrixDescriptor(rows: samples.count,
                                                          columns: controlPointCount,
                                                          rowBytes: controlPointCount * 4,
                                                          dataType: .float32))
        N.data.label = "N matrix"
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            throw MetalError.cannotMakeCommandBuffer
        }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Cannot create compute command encoder")
            throw MetalError.cannotMakeComputeCommandEncoder
        }
        
        encoder.setComputePipelineState(Self.surfaceMatrixFillerState)
        encoder.setBytes([BSplineKernelArgument(degree: Int32(uBasis.degree),
                                                knotCount: Int32(uBasis.multiplicitySum))],
                         length: MemoryLayout<BSplineKernelArgument>.size,
                         index: 0)
        encoder.setBytes([BSplineKernelArgument(degree: Int32(vBasis.degree),
                                                knotCount: Int32(vBasis.multiplicitySum))],
                         length: MemoryLayout<BSplineKernelArgument>.size,
                         index: 1)
        encoder.setBuffer(uBasis.knotBuffer, offset: 0, index: 2)
        encoder.setBuffer(vBasis.knotBuffer, offset: 0, index: 3)
        encoder.setBytes([Int32(controlPointCount)],
                         length: MemoryLayout<Int32>.size,
                         index: 4)
        encoder.setBuffer(N.data, offset: 0, index: 5)
        encoder.setBytes(samples.map { $0.0.x }, length: MemoryLayout<Float>.stride * samples.count, index: 6)
        encoder.setBytes(samples.map { $0.0.y }, length: MemoryLayout<Float>.stride * samples.count, index: 7)
        encoder.dispatchThreadgroups(MTLSizeMake(samples.count, 1, 1),
                                     threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let SData = samples.map { [$0.1.x, $0.1.y, $0.1.z] }.flatMap { $0 }
        let SBuffer = MetalSystem.shared.device.makeBuffer(bytes: SData,
                                               length: SData.count * MemoryLayout<Float>.stride)!
        SBuffer.label = "S Buffer"
        let S = MPSMatrix(buffer: SBuffer,
                          descriptor: MPSMatrixDescriptor(rows: samples.count,
                                                          columns: 3,
                                                          rowBytes: 3 * 4,
                                                          dataType: .float32))
        
        guard let NtN = MatrixUtility.multiplicate(N, transposeLhs: true, N,
                                                   resultMatrixLabel: "NtN",
                                                   commandBufferLabel: "Multiply Nt & N") else {
            print("Fail to multiply Nt and N")
            throw PhantomError.unknown("Fail to multiply Nt and N")
        }
        
        guard let R = MatrixUtility.multiplicate(N, transposeLhs: true, S,
                                                 resultMatrixLabel: "NtS",
                                                 commandBufferLabel: "Multiply Nt & S") else {
            print("Fail to multiply Nt & S")
            throw PhantomError.unknown("Fail to multiply Nt & S")
        }
        
        guard let P = MatrixUtility.solve(spdMatrix: NtN, b: R,
                                          resultMatrixLabel: "P (Final Result)",
                                          commandBufferLabel: "Solve P") else {
            print("Fail to solve P")
            throw PhantomError.unknown("Fail to solve P")
        }
        
#if false
        captureManager.stopCapture()
#endif
        
        let pointer = P.data.contents()
        var controlNet: [[SIMD4<Float>]] = []
        var byteOffset: Int = 0
        for _ in 0..<vControlPointCount {
            var tempCPS: [SIMD4<Float>] = []
            for _ in 0..<uControlPointCount {
                let x = pointer.load(fromByteOffset: byteOffset, as: Float.self)
                let y = pointer.load(fromByteOffset: byteOffset + 4, as: Float.self)
                let z = pointer.load(fromByteOffset: byteOffset + 8, as: Float.self)
                byteOffset = byteOffset + 12
                tempCPS.append(.init(x: x, y: y, z: z, w: 1))
            }
            controlNet.append(tempCPS)
        }
        
        let fittedSurface = BSplineSurface(uKnots: uBasis.knots,
                                           vKnots: vBasis.knots,
                                           degrees: (uBasis.degree, vBasis.degree),
                                           controlNet: controlNet)
        
        return fittedSurface
    }
}
