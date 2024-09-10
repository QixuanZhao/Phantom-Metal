//
//  BSplineApproximator.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/1.
//

import Foundation
import MetalPerformanceShaders

extension BSplineBasis {
    static func fillKnots(in knots: [Knot], count: Int = 0) -> [Knot] {
        if count < 1 { return knots }
        
        var result = knots
        var spans: [ClosedRange<Float>] = []
        for i in 1..<knots.count {
            spans.append(knots[i - 1].value...knots[i].value)
        }
        spans.sort(by: { ($0.upperBound - $0.lowerBound) > ($1.upperBound - $1.lowerBound) })
        
        for _ in 0..<count {
            let longestSpan = spans.removeFirst()
            let middlePoint = (longestSpan.upperBound + longestSpan.lowerBound) / 2
            let length = (longestSpan.upperBound - longestSpan.lowerBound) / 2
            let leftSpan = longestSpan.lowerBound...middlePoint
            let rightSpan = middlePoint...longestSpan.upperBound
            
            let upperBoundIndex = result.firstIndex(where: { $0.value > middlePoint })!
            result.insert(Knot(value: middlePoint, multiplicity: 1), at: upperBoundIndex)
            
            if let index = spans.firstIndex(where: { ($0.upperBound - $0.lowerBound) <= length }) {
                spans.insert(contentsOf: [leftSpan, rightSpan], at: index)
            } else {
                spans.append(contentsOf: [leftSpan, rightSpan])
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

class BSplineApproximator {
    static private var surfaceMatrixFillerState: MTLComputePipelineState = {
        return try! system.device.makeComputePipelineState(function: system.library.makeFunction(name: "surfaceFiller")!)
    }()
    
    static private var uIsoCurveConstraintFiller: MTLComputePipelineState = {
        return try! system.device.makeComputePipelineState(function: system.library.makeFunction(name: "uIsoCurveConstraintFiller")!)
    }()
    
    static private var vIsoCurveConstraintFiller: MTLComputePipelineState = {
        return try! system.device.makeComputePipelineState(function: system.library.makeFunction(name: "vIsoCurveConstraintFiller")!)
    }()
    
    struct GuidanceResult {
        let originalSurface: BSplineSurface
        let modifiedSurface: BSplineSurface
        let averageError: Float
    }
    
    // sample: (parameters, ideal spatial position)
    static func guide(originalSurface surface: BSplineSurface,
                      samples: [(SIMD2<Float>, SIMD3<Float>)],
                      isoU: [Float] = [0, 1],
                      isoV: [Float] = [0, 1],
                      knotDensityFactor: Int = 1
    ) throws -> GuidanceResult {
        var innerIsoU = isoU
        var innerIsoV = isoV
        
        innerIsoU.removeFirst()
        innerIsoU.removeLast()
        innerIsoV.removeFirst()
        innerIsoV.removeLast()
        
        let blendUKnots = BSplineBasis.fillKnots(in: BSplineBasis.averageKnots(for: isoU, withDegree: surface.uBasis.degree),
                                                 count: (isoU.count + 2) * knotDensityFactor - 2)
        let blendVKnots = BSplineBasis.fillKnots(in: BSplineBasis.averageKnots(for: isoV, withDegree: surface.vBasis.degree),
                                                 count: (isoV.count + 2) * knotDensityFactor - 2)
        
        let blendUBasis = BSplineBasis(degree: surface.uBasis.degree, knots: blendUKnots)
        let blendVBasis = BSplineBasis(degree: surface.vBasis.degree, knots: blendVKnots)
        
        let blankUSamples = blendUBasis.sample()
        let blankVSamples = blendVBasis.sample()
        
        print("BUS: \(blankUSamples)")
        print("BVS: \(blankVSamples)")
        
        let givenSamples: [(SIMD2<Float>, SIMD3<Float>, Float)] = samples.map {
            ($0.0, $0.1 - surface.point(at: $0.0)!, 1)
        }
        
        var samples: [(SIMD2<Float>, SIMD3<Float>, Float)] = []
        for u in blankUSamples {
            for v in blankVSamples {
                var nearestDistance: Float = 1
                givenSamples.forEach { nearestDistance = min(nearestDistance, distance($0.0, [u, v])) }
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
        let WBuffer = system.device.makeBuffer(bytes: weights, length: weights.count * MemoryLayout<Float>.stride)!
        let W = MPSMatrix(buffer: WBuffer,
                          descriptor: MPSMatrixDescriptor(rows: samples.count,
                                                          columns: samples.count,
                                                          rowBytes: samples.count * 4,
                                                          dataType: .float32))
        
        let N = MPSMatrix(device: system.device,
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
        let MBuffer = system.device.makeBuffer(bytes: MData, length: MData.count * MemoryLayout<Float>.stride)!
        
        let M = MPSMatrix(buffer: MBuffer,
                          descriptor: MPSMatrixDescriptor(rows: MRows,
                                                          columns: controlPointCount,
                                                          rowBytes: controlPointCount * 4,
                                                          dataType: .float32))
        M.data.label = "M matrix"
        
        let SData = samples.map { [$0.1.x, $0.1.y, $0.1.z] }.flatMap { $0 }
        let SBuffer = system.device.makeBuffer(bytes: SData,
                                               length: SData.count * MemoryLayout<Float>.stride)!
        SBuffer.label = "S Buffer"
        let S = MPSMatrix(buffer: SBuffer,
                          descriptor: MPSMatrixDescriptor(rows: samples.count,
                                                          columns: 3,
                                                          rowBytes: 3 * 4,
                                                          dataType: .float32))
        
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = system.device
        
#if false
        do {
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            fatalError("error when trying to capture: \(error)")
        }
#endif
        
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            throw MetalError.cannotMakeCommandBuffer
        }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Cannot create compute command encoder")
            throw MetalError.cannotMakeComputeCommandEncoder
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
        encoder.setBytes(samples.map { $0.0.x }, length: MemoryLayout<Float>.stride * samples.count, index: 6)
        encoder.setBytes(samples.map { $0.0.y }, length: MemoryLayout<Float>.stride * samples.count, index: 7)
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
            print("Fail to multiply Nt and W")
            throw PhantomError.unknownError("Fail to multiply Nt and W")
        }
        
        guard let NtWN = MatrixUtility.multiplicate(NtW, N,
                                                    resultMatrixLabel: "NtWN",
                                                    commandBufferLabel: "Multiply NtW & N") else {
            print("Fail to multiply NtW and N")
            throw PhantomError.unknownError("Fail to multiply NtW and N")
        }
        
        guard let NtWN_inversion = MatrixUtility.inverse(spdMatrix: NtWN,
                                                         resultMatrixLabel: "inversion of NtWN (referred to as NtWNi)",
                                                         commandBufferLabel: "Invert NtWN") else {
            print("Fail to inverse NtWN")
            throw PhantomError.unknownError("Fail to inverse NtWN")
        }
        
        if let _ = MatrixUtility.multiplicate(NtWN_inversion, NtWN,
                                              resultMatrixLabel: "Identity Matrix",
                                              commandBufferLabel: "Inversion Check") {
            print("Identity Matrix Check")
        }
        
        guard let Mi = MatrixUtility.multiplicate(M, NtWN_inversion, resultMatrixLabel: "Mi (M * NtWNi)", commandBufferLabel: "Multiply M & NtWNi") else {
            print("Fail to multiply M & (NtWN)^-1")
            throw PhantomError.unknownError("Fail to multiply M & (NtWN)^-1")
        }
        
        guard let MiMt = MatrixUtility.multiplicate(Mi, M, transposeRhs: true, resultMatrixLabel: "MiMt", commandBufferLabel: "Multiply Mi & Mt") else {
            print("Fail to multiply Mi & Mt")
            throw PhantomError.unknownError("Fail to multiply Mi & Mt")
        }
        
        guard let NtWS = MatrixUtility.multiplicate(NtW, S, resultMatrixLabel: "NtWS (Right Hand Side)", commandBufferLabel: "Multiply NtW & S") else {
            print("Fail to multiply NtW and S")
            throw PhantomError.unknownError("Fail to multiply NtW and S")
        }
        
        guard let MiNtWS = MatrixUtility.multiplicate(Mi, NtWS, resultMatrixLabel: "MiNtWS", commandBufferLabel: "Multiply Mi & NtWS") else {
            print("Fail to multiply Mi & NtWS")
            throw PhantomError.unknownError("Fail to multiply Mi & NtWS")
        }
        
        // MiMt is not positive-definite
        guard let A = MatrixUtility.solve(matrix: MiMt, b: MiNtWS, resultMatrixLabel: "A (Lagrange Multipliers)", commandBufferLabel: "Solve A") else {
            print("Fail to solve A")
            throw PhantomError.unknownError("Fail to solve A")
        }
        
        let rightHandSides = NtWS
        guard MatrixUtility.fma(alpha: -1, A: M, transposeA: true, B: A, beta: 1, C: rightHandSides, commandBufferLabel: "FMA") else {
            print("Fail to compute right hand side")
            throw PhantomError.unknownError("Fail to compute right hand side")
        }
        
//        // NtN_inversion is not positive-definite
//        guard let P = MatrixUtility.solve(matrix: NtWN_inversion, b: rightHandSides, resultMatrixLabel: "P (Final Result)", commandBufferLabel: "Solve P") else {
//            print("Fail to solve P")
//            throw PhantomError.unknownError("Fail to solve P")
//        }
        
        guard let NtWN2 = MatrixUtility.multiplicate(NtW, N,
                                                     resultMatrixLabel: "NtWN 2",
                                                     commandBufferLabel: "Multiply NtW & N 2") else {
            print("Fail to multiply NtW and N 2")
            throw PhantomError.unknownError("Fail to multiply NtW and N 2")
        }
        
        guard let P = MatrixUtility.solve(spdMatrix: NtWN2, b: rightHandSides,
                                          resultMatrixLabel: "P (Final Result)",
                                          commandBufferLabel: "Solve P") else {
            print("Fail to solve P")
            throw PhantomError.unknownError("Fail to solve P")
        }
        
//        guard let P = MatrixUtility.multiplicate(NtWN_inversion, rightHandSides,
//                                                 resultMatrixLabel: "P (Final Result)",
//                                                 commandBufferLabel: "Solve P") else {
//            print("Fail to solve P")
//            throw PhantomError.unknownError("Fail to solve P")
//        }
        
#if false
        captureManager.stopCapture()
#endif
        
        print("Succeed P(\(P.rows), \(P.columns))")
        
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
        
        let modificationSurface = BSplineSurface(uKnots: blendUKnots,
                                                 vKnots: blendVKnots,
                                                 degrees: (blendUBasis.degree, blendVBasis.degree),
                                                 controlNet: controlNet)
        
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
                                  averageError: -1)
    }
    
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
    
    static func approximate(samples: [(SIMD2<Float>, SIMD3<Float>)],
                            uBasis: BSplineBasis,
                            vBasis: BSplineBasis) throws -> BSplineSurface {
        
        let uControlPointCount = uBasis.multiplicitySum - uBasis.order
        let vControlPointCount = vBasis.multiplicitySum - vBasis.order
        
        let controlPointCount = uControlPointCount * vControlPointCount
        
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = system.device
        
#if false
        do {
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            fatalError("error when trying to capture: \(error)")
        }
#endif
        
        let N = MPSMatrix(device: system.device,
                          descriptor: MPSMatrixDescriptor(rows: samples.count,
                                                          columns: controlPointCount,
                                                          rowBytes: controlPointCount * 4,
                                                          dataType: .float32))
        N.data.label = "N matrix"
        
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else {
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
        let SBuffer = system.device.makeBuffer(bytes: SData,
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
            throw PhantomError.unknownError("Fail to multiply Nt and N")
        }
        
        guard let R = MatrixUtility.multiplicate(N, transposeLhs: true, S,
                                                 resultMatrixLabel: "NtS",
                                                 commandBufferLabel: "Multiply Nt & S") else {
            print("Fail to multiply Nt & S")
            throw PhantomError.unknownError("Fail to multiply Nt & S")
        }
        
        guard let P = MatrixUtility.solve(spdMatrix: NtN, b: R,
                                          resultMatrixLabel: "P (Final Result)",
                                          commandBufferLabel: "Solve P") else {
            print("Fail to solve P")
            throw PhantomError.unknownError("Fail to solve P")
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
