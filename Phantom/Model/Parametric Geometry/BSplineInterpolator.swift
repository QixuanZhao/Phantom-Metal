//
//  BSplineInterpolator.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/21.
//

import simd
import MetalPerformanceShaders

extension BSplineBasis {
    static func averageKnots(for parameters: [Float],
                             withDegree degree: Int) -> [Knot] {
        let innerKnotMultiplicitySum = parameters.count - degree - 1
        var knots: [Knot] = [.init(value: parameters.first!, multiplicity: degree + 1)]
        if innerKnotMultiplicitySum >= 1 {
            for i in 1...innerKnotMultiplicitySum {
                var knot: Float = 0
                for j in i..<i + degree {
                    knot = knot + parameters[j]
                }
                knot = knot / Float(degree)
                knots.append(.init(value: knot, multiplicity: 1))
            }
        }
        knots.append(.init(value: parameters.last!, multiplicity: degree + 1))
        return knots
    }
}

enum MetalPerformanceShadersError: Error {
    case mpsNotSupported
}

struct BSplineKernelArgument {
    var degree: Int32
    var knotCount: Int32
}

class BSplineInterpolator {
    static private var matrixFillerState: MTLComputePipelineState = {
        return try! system.device.makeComputePipelineState(function: system.library.makeFunction(name: "curveFiller")!)
    }()
    
    static func evaluateParametersByChordLength(for points: [SIMD3<Float>]) -> [Float] {
        var d: Float = 0
        var parameters: [Float] = [0]
        for i in 1..<points.count {
            d = d + distance(points[i], points[i - 1])
            parameters.append(d)
        }
        
        return parameters.map { $0 / d }
    }
    
    static func evaluateParametersByChordLength(for curves: [BSplineCurve]) -> [Float] {
        evaluateParametersByChordLength(for: curves.map {
            var representativePoint: SIMD4<Float> = .zero
            $0.controlPoints.forEach { representativePoint = representativePoint + $0 }
            representativePoint = representativePoint / Float($0.controlPoints.count)
            return .init(x: representativePoint.x, y: representativePoint.y, z: representativePoint.z) / representativePoint.w
        })
    }
    
    static func makeCompatible(_ curves: [BSplineCurve]) -> [BSplineCurve] {
        let commonKnots = BSplineBasis.commonKnots(of: curves.map { $0.basis })
        
        return curves.map {
            let processedCurve = BSplineCurve(knots: $0.basis.knots,
                                              controlPoints: $0.controlPoints,
                                              degree: $0.basis.degree)
            var index = 0
            for knot in commonKnots {
                if index >= processedCurve.basis.knots.count {
                    return processedCurve
                }
                
                if processedCurve.basis.knots[index].value > knot.value {
                    for _ in 0..<knot.multiplicity {
                        processedCurve.insert(knotValue: knot.value)
                    }
                    index = index + 1
                }
                
                if processedCurve.basis.knots[index].value == knot.value {
                    if processedCurve.basis.knots[index].multiplicity < knot.multiplicity {
                        for _ in processedCurve.basis.knots[index].multiplicity..<knot.multiplicity {
                            processedCurve.insert(knotValue: knot.value)
                        }
                    }
                    index = index + 1
                }
            }
            return processedCurve
        }
    }
    
    static func makeCompatible(_ surfaces: [BSplineSurface]) -> [BSplineSurface] {
        let commonUKnots = BSplineBasis.commonKnots(of: surfaces.map { $0.uBasis })
        let commonVKnots = BSplineBasis.commonKnots(of: surfaces.map { $0.vBasis })
        
        return surfaces.map {
            let processedSurface = BSplineSurface(uKnots: $0.uBasis.knots,
                                                  vKnots: $0.vBasis.knots,
                                                  degrees: ($0.uBasis.degree, $0.vBasis.degree),
                                                  controlNet: $0.controlNet)
            var index = 0
            for uk in commonUKnots {
                if processedSurface.uBasis.knots[index].value > uk.value {
                    for _ in 0..<uk.multiplicity { processedSurface.insert(uKnot: uk.value) }
                    index = index + 1
                }
                
                if processedSurface.uBasis.knots[index].value == uk.value {
                    if processedSurface.uBasis.knots[index].multiplicity < uk.multiplicity {
                        for _ in processedSurface.uBasis.knots[index].multiplicity..<uk.multiplicity {
                            processedSurface.insert(uKnot: uk.value)
                        }
                    }
                    index = index + 1
                }
            }
            
            index = 0
            for vk in commonVKnots {
                if processedSurface.vBasis.knots[index].value > vk.value {
                    for _ in 0..<vk.multiplicity { processedSurface.insert(vKnot: vk.value) }
                    index = index + 1
                }
                
                if processedSurface.vBasis.knots[index].value == vk.value {
                    if processedSurface.vBasis.knots[index].multiplicity < vk.multiplicity {
                        for _ in processedSurface.vBasis.knots[index].multiplicity..<vk.multiplicity {
                            processedSurface.insert(vKnot: vk.value)
                        }
                    }
                    index = index + 1
                }
            }
            
            return processedSurface
        }
    }
    
    struct InterpolationResult {
        let points: [SIMD3<Float>]
        let blendBasis: BSplineBasis
        let blendParameters: [Float]
        let curve: BSplineCurve
    }
    
    static func interpolate(points: [SIMD3<Float>],
                            idealDegree: Int = 3) throws -> InterpolationResult {
        let parameters = evaluateParametersByChordLength(for: points)
        return try interpolate(points: points, parameters: parameters, idealDegree: idealDegree)
    }
    
    static func interpolate(points: [SIMD3<Float>],
                            parameters: [Float],
                            idealDegree: Int = 3) throws -> InterpolationResult {
        let degree = min(points.count - 1, idealDegree)
        let knots = BSplineBasis.averageKnots(for: parameters, withDegree: degree)
        let blendBasis = BSplineBasis(degree: degree, knots: knots)
        
        guard MPSSupportsMTLDevice(system.device) else {
            print("MPS not supported on this device")
            throw MetalPerformanceShadersError.mpsNotSupported
        }
        
        let descriptor = MPSMatrixDescriptor(rows: points.count,
                                             columns: points.count,
                                             rowBytes: points.count * 4,
                                             dataType: .float32)
        let bDescriptor = MPSMatrixDescriptor(rows: points.count,
                                              columns: 3,
                                              rowBytes: 12,
                                              dataType: .float32)
        let pDescriptor = MPSMatrixDescriptor(rows: 1,
                                              columns: points.count,
                                              rowBytes: points.count * 4,
                                              dataType: .uInt32)
        
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            throw MetalError.cannotMakeCommandBuffer
        }
        
        guard let argsBuffer = system.device.makeBuffer(length: MemoryLayout<BSplineKernelArgument>.size,
                                                        options: .storageModeShared) else {
            print("Cannot make argument buffer")
            throw MetalError.cannotMakeBuffer
        }
        
        guard let sampleBuffer = system.device.makeBuffer(bytes: parameters,
                                                          length: MemoryLayout<Float>.stride * parameters.count) else {
            print("Cannot make sample buffer")
            throw MetalError.cannotMakeBuffer
        }
        let arguments = BSplineKernelArgument(degree: Int32(degree),
                                              knotCount: Int32(blendBasis.multiplicitySum))
        argsBuffer.contents().storeBytes(of: arguments, as: BSplineKernelArgument.self)
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Cannot make compute command encoder")
            throw MetalError.cannotMakeComputeCommandEncoder
        }
        
        let A = MPSMatrix(device: system.device, descriptor: descriptor)
        let pivotIndices = MPSMatrix(device: system.device, descriptor: pDescriptor)
        let decomposer = MPSMatrixDecompositionLU(device: system.device,
                                                  rows: A.rows,
                                                  columns: A.columns)
        
        encoder.setComputePipelineState(Self.matrixFillerState)
        encoder.setBuffer(argsBuffer, offset: 0, index: 0)
        encoder.setBuffer(blendBasis.knotBuffer, offset: 0, index: 1)
        encoder.setBytes([points.count], length: MemoryLayout.size(ofValue: points.count), index: 2)
        encoder.setBuffer(A.data, offset: 0, index: 3)
        encoder.setBuffer(sampleBuffer, offset: 0, index: 4)
        
        let threadsPerThreadgroup = MTLSize(width: points.count, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: 1, height: 1, depth: 1)
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            throw MetalError.cannotMakeCommandBuffer
        }
        
        decomposer.encode(commandBuffer: commandBuffer,
                          sourceMatrix: A,
                          resultMatrix: A,
                          pivotIndices: pivotIndices,
                          info: nil)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let B: [Float] = points.map { [$0.x, $0.y, $0.z] }.flatMap { $0 }
        
        guard let buffer = system.device.makeBuffer(bytes: B,
                                                    length: B.count * MemoryLayout<Float>.stride) else {
            print("Cannot make matrix buffer")
            throw MetalError.cannotMakeBuffer
        }
        
        let b = MPSMatrix(buffer: buffer, descriptor: bDescriptor)
        let solution = MPSMatrix(device: system.device, descriptor: bDescriptor)
        
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            throw MetalError.cannotMakeCommandBuffer
        }
        
        let solver = MPSMatrixSolveLU(device: system.device,
                                      transpose: false,
                                      order: points.count,
                                      numberOfRightHandSides: 3)
        
        solver.encode(commandBuffer: commandBuffer,
                      sourceMatrix: A,
                      rightHandSideMatrix: b,
                      pivotIndices: pivotIndices,
                      solutionMatrix: solution)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        var controlPointsAfterInterpolation: [SIMD4<Float>] = []
        let pointer = solution.data.contents()
        var offset = 0
        for _ in 0..<points.count {
            let x = pointer.load(fromByteOffset: offset, as: Float.self)
            let y = pointer.load(fromByteOffset: offset + 4, as: Float.self)
            let z = pointer.load(fromByteOffset: offset + 8, as: Float.self)
            offset = offset + 12
            controlPointsAfterInterpolation.append(.init(x: x, y: y, z: z, w: 1))
        }
        
        let curve = BSplineCurve(basis: blendBasis,
                                 controlPoints: controlPointsAfterInterpolation)
        
        return InterpolationResult(points: points, 
                                   blendBasis: blendBasis,
                                   blendParameters: parameters, 
                                   curve: curve)
    }
    
    struct LoftResult {
        let originalSections: [BSplineCurve]
        let processedSections: [BSplineCurve]
        let blendBasis: BSplineBasis
        let blendParameters: [Float]
        let blendParameter: BasisParameter
        let surface: BSplineSurface
    }
    
    enum LoftError: Error {
    case sectionsNotEnough(Int)
    case inconsistentDegrees(Int, Int)
    case differentKnotVectors
    }
    
    enum BasisParameter {
        case u, v
    }
    
    static func loft(sections: [BSplineCurve],
                     blendParameter: BasisParameter = .v,
                     idealDegree: Int = 3) throws -> LoftResult {
        try loft(sections: sections,
                 blendParameter: blendParameter,
                 parameters: evaluateParametersByChordLength(for: sections),
                 idealDegree: idealDegree)
    }
    
    static func loft(sections: [BSplineCurve],
                     blendParameter: BasisParameter = .v,
                     parameters: [Float],
                     idealDegree: Int = 3) throws -> LoftResult {
        guard MPSSupportsMTLDevice(system.device) else {
            print("MPS not supported on this device")
            throw MetalPerformanceShadersError.mpsNotSupported
        }
        
        guard sections.count > 1 else {
            print("Section curves are not enough.")
            throw LoftError.sectionsNotEnough(sections.count)
        }
        
        let degree = min(sections.count - 1, idealDegree)
        let knots = BSplineBasis.averageKnots(for: parameters, withDegree: degree)
        let blendBasis = BSplineBasis(degree: degree, knots: knots)
        
        let processedSections: [BSplineCurve] = makeCompatible(sections)
        
        let descriptor = MPSMatrixDescriptor(rows: processedSections.count,
                                             columns: processedSections.count,
                                             rowBytes: processedSections.count * 4,
                                             dataType: .float32)
        let bDescriptor = MPSMatrixDescriptor(rows: processedSections.count,
                                              columns: 3,
                                              rowBytes: 12,
                                              dataType: .float32)
        let pDescriptor = MPSMatrixDescriptor(rows: 1,
                                              columns: processedSections.count,
                                              rowBytes: processedSections.count * 4,
                                              dataType: .uInt32)

        
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            throw MetalError.cannotMakeCommandBuffer
        }
        
        guard let argsBuffer = system.device.makeBuffer(length: MemoryLayout<BSplineKernelArgument>.size,
                                                        options: .storageModeShared) else {
            print("Cannot make argument buffer")
            throw MetalError.cannotMakeBuffer
        }
        
        guard let sampleBuffer = system.device.makeBuffer(bytes: parameters, 
                                                          length: MemoryLayout<Float>.stride * parameters.count) else {
            print("Cannot make sample buffer")
            throw MetalError.cannotMakeBuffer
        }
        let arguments = BSplineKernelArgument(degree: Int32(degree),
                                              knotCount: Int32(blendBasis.multiplicitySum))
        argsBuffer.contents().storeBytes(of: arguments, as: BSplineKernelArgument.self)
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Cannot make compute command encoder")
            throw MetalError.cannotMakeComputeCommandEncoder
        }
        
        let A = MPSMatrix(device: system.device, descriptor: descriptor)
        let pivotIndices = MPSMatrix(device: system.device, descriptor: pDescriptor)
        let decomposer = MPSMatrixDecompositionLU(device: system.device,
                                                  rows: A.rows,
                                                  columns: A.columns)
        
        encoder.setComputePipelineState(Self.matrixFillerState)
        encoder.setBuffer(argsBuffer, offset: 0, index: 0)
        encoder.setBuffer(blendBasis.knotBuffer, offset: 0, index: 1)
        encoder.setBytes([processedSections.count], length: MemoryLayout.size(ofValue: processedSections.count), index: 2)
        encoder.setBuffer(A.data, offset: 0, index: 3)
        encoder.setBuffer(sampleBuffer, offset: 0, index: 4)
        
        let threadsPerThreadgroup = MTLSize(width: processedSections.count, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: 1, height: 1, depth: 1)
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            throw MetalError.cannotMakeCommandBuffer
        }
        
        decomposer.encode(commandBuffer: commandBuffer,
                          sourceMatrix: A,
                          resultMatrix: A,
                          pivotIndices: pivotIndices,
                          info: nil)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        var b: [MPSMatrix] = []
        var solution: [MPSMatrix] = []
        var B: [[Float]] = .init(repeating: [], count: processedSections.first!.controlPoints.count)
        
        for section in processedSections {
            for i in 0..<section.controlPoints.count {
                B[i].append(section.controlPoints[i].x)
                B[i].append(section.controlPoints[i].y)
                B[i].append(section.controlPoints[i].z)
            }
        }
        for i in 0..<processedSections.first!.controlPoints.count {
            guard let buffer = system.device.makeBuffer(bytes: B[i],
                                                        length: B[i].count * MemoryLayout<Float>.stride) else {
                print("Cannot make matrix buffer")
                throw MetalError.cannotMakeBuffer
            }
            
            let matrix = MPSMatrix(buffer: buffer, descriptor: bDescriptor)
            b.append(matrix)
            solution.append(MPSMatrix(device: system.device, descriptor: bDescriptor))
        }
        
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            throw MetalError.cannotMakeCommandBuffer
        }
        
        let solver = MPSMatrixSolveLU(device: system.device,
                                      transpose: false,
                                      order: processedSections.count,
                                      numberOfRightHandSides: 3)
        
        for i in 0..<processedSections.first!.controlPoints.count {
            solver.encode(commandBuffer: commandBuffer,
                          sourceMatrix: A,
                          rightHandSideMatrix: b[i],
                          pivotIndices: pivotIndices,
                          solutionMatrix: solution[i])
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        var controlPointsAfterInterpolation: [[SIMD4<Float>]] = .init(repeating: [], count: processedSections.first!.controlPoints.count)
        for i in 0..<processedSections.first!.controlPoints.count {
            let pointer = solution[i].data.contents()
            var offset = 0
            for _ in 0..<processedSections.count {
                let x = pointer.load(fromByteOffset: offset, as: Float.self)
                let y = pointer.load(fromByteOffset: offset + 4, as: Float.self)
                let z = pointer.load(fromByteOffset: offset + 8, as: Float.self)
                offset = offset + 12
                controlPointsAfterInterpolation[i].append(.init(x: x, y: y, z: z, w: 1))
            }
        }
        let surface = switch blendParameter {
        case .u:
            BSplineSurface(uKnots: blendBasis.knots,
                           vKnots: processedSections.first!.basis.knots,
                           degrees: (blendBasis.degree, processedSections.first!.basis.degree),
                           controlNet: controlPointsAfterInterpolation)
        case .v:
            BSplineSurface(uKnots: processedSections.first!.basis.knots,
                           vKnots: blendBasis.knots,
                           degrees: (processedSections.first!.basis.degree, blendBasis.degree),
                           controlNet: (0..<controlPointsAfterInterpolation.first!.count).map { i in
                controlPointsAfterInterpolation.map { $0[i] }
            })
        }
        
        return LoftResult(originalSections: sections, 
                          processedSections: processedSections,
                          blendBasis: blendBasis,
                          blendParameters: parameters,
                          blendParameter: blendParameter,
                          surface: surface)
    }
    
}
