//
//  MatrixUtility.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/6.
//

import MetalPerformanceShaders

@MainActor
class MatrixUtility {
    
    static func copy(matrix: MPSMatrix, label: String? = nil) throws -> MPSMatrix {
        let copier = MPSMatrixCopy(device: MetalSystem.shared.device,
                                   copyRows: matrix.rows,
                                   copyColumns: matrix.columns,
                                   sourcesAreTransposed: false,
                                   destinationsAreTransposed: false)
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            throw PhantomError.unknown("Cannot create command buffer")
        }
        
        let destination = MPSMatrix(device: MetalSystem.shared.device,
                                    descriptor: MPSMatrixDescriptor(rows: matrix.rows, columns: matrix.columns, rowBytes: matrix.rowBytes, dataType: matrix.dataType))
        destination.data.label = label
        copier.encode(commandBuffer: commandBuffer,
                      copyDescriptor: MPSMatrixCopyDescriptor(sourceMatrix: matrix,
                                                              destinationMatrix: destination,
                                                              offsets: MPSMatrixCopyOffsets()))
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return destination
    }
    
    @discardableResult
    static func fma(alpha: Double,
                    A: MPSMatrix,
                    transposeA: Bool = false,
                    B: MPSMatrix,
                    transposeB: Bool = false,
                    beta: Double,
                    C: MPSMatrix,
                    commandBufferLabel: String? = nil) -> Bool {
        let ripeARows = transposeA ? A.columns : A.rows
        let ripeBRows = transposeB ? B.columns : B.rows
        let ripeAColumns = transposeA ? A.rows : A.columns
        let ripeBColumns = transposeB ? B.rows : B.columns
        
        guard ripeAColumns == ripeBRows else { return false }
        guard ripeARows == C.rows else { return false }
        guard ripeBColumns == C.columns else { return false }
        
        let multiplication = MPSMatrixMultiplication(device: MetalSystem.shared.device,
                                                     transposeLeft: transposeA,
                                                     transposeRight: transposeB,
                                                     resultRows: C.rows,
                                                     resultColumns: C.columns,
                                                     interiorColumns: ripeAColumns,
                                                     alpha: alpha,
                                                     beta: beta)
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else { return false }
        commandBuffer.label = commandBufferLabel
        
        multiplication.encode(commandBuffer: commandBuffer,
                              leftMatrix: A,
                              rightMatrix: B, 
                              resultMatrix: C)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return true
    }
    
    static func multiplicate(_ lhs: MPSMatrix,
                             transposeLhs: Bool = false,
                             _ rhs: MPSMatrix,
                             transposeRhs: Bool = false,
                             resultMatrixLabel: String? = nil,
                             commandBufferLabel: String? = nil) -> MPSMatrix? {
        let resultMatrixRows = transposeLhs ? lhs.columns : lhs.rows
        let resultMatrixColumns = transposeRhs ? rhs.rows : rhs.columns
        
        let innerColumnsFromLhs = transposeLhs ? lhs.rows : lhs.columns
        let innerColumnsFromRhs = transposeRhs ? rhs.columns : rhs.rows
        
        guard innerColumnsFromLhs == innerColumnsFromRhs else { return nil }
        
        let innerColumns = innerColumnsFromLhs
        
        let result = MPSMatrix(device: MetalSystem.shared.device,
                               descriptor: MPSMatrixDescriptor(rows: resultMatrixRows,
                                                               columns: resultMatrixColumns,
                                                               rowBytes: resultMatrixColumns * 4,
                                                               dataType: .float32))
        result.data.label = resultMatrixLabel
        
        let multiplication = MPSMatrixMultiplication(device: MetalSystem.shared.device,
                                                     transposeLeft: transposeLhs,
                                                     transposeRight: transposeRhs,
                                                     resultRows: resultMatrixRows,
                                                     resultColumns: resultMatrixColumns,
                                                     interiorColumns: innerColumns,
                                                     alpha: 1, beta: 0)
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            return nil
        }
        commandBuffer.label = commandBufferLabel
        
        multiplication.encode(commandBuffer: commandBuffer,
                              leftMatrix: lhs, 
                              rightMatrix: rhs,
                              resultMatrix: result)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return result
    }
    
    static func solve(spdMatrix matrix: MPSMatrix,
                      storageMatrix decompositionResult: MPSMatrix,
                      statusBuffer: MTLBuffer,
                      b: MPSMatrix,
                      solver: MPSMatrixSolveCholesky,
                      result: MPSMatrix,
                      commandBufferLabel: String? = nil) -> MPSMatrixDecompositionStatus? {
        guard matrix.rows == b.rows else { return nil }
        guard matrix.rows == matrix.columns else { return nil }
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            return nil
        }
        commandBuffer.label = commandBufferLabel
        
        let order = matrix.rows
        let decomposer = MPSMatrixDecompositionCholesky(device: MetalSystem.shared.device, lower: false, order: order)
        decomposer.encode(commandBuffer: commandBuffer,
                          sourceMatrix: matrix,
                          resultMatrix: decompositionResult,
                          status: statusBuffer)
        
        solver.encode(commandBuffer: commandBuffer,
                      sourceMatrix: decompositionResult,
                      rightHandSideMatrix: b,
                      solutionMatrix: result)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return statusBuffer.contents().load(as: MPSMatrixDecompositionStatus.self)
    }
    
    static func solve(spdMatrix matrix: MPSMatrix, 
                      b: MPSMatrix,
                      resultMatrixLabel: String? = nil,
                      commandBufferLabel: String? = nil) -> MPSMatrix? {
        guard matrix.rows == b.rows else { return nil }
        guard matrix.rows == matrix.columns else { return nil }
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            return nil
        }
        commandBuffer.label = commandBufferLabel
        
        let order = matrix.rows
        
        let decompositionResult = MPSMatrix(device: MetalSystem.shared.device,
                                            descriptor: MPSMatrixDescriptor(rows: matrix.rows,
                                                                            columns: matrix.columns,
                                                                            rowBytes: matrix.rowBytes,
                                                                            dataType: matrix.dataType))
        
        let decomposer = MPSMatrixDecompositionCholesky(device: MetalSystem.shared.device, lower: false, order: order)
        let decompositionStatus = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<MPSMatrixDecompositionStatus>.size)!
        decomposer.encode(commandBuffer: commandBuffer,
                          sourceMatrix: matrix,
                          resultMatrix: decompositionResult,
                          status: decompositionStatus)
        
        let solution = MPSMatrix(device: MetalSystem.shared.device,
                                 descriptor: MPSMatrixDescriptor(rows: b.rows,
                                                                 columns: b.columns,
                                                                 rowBytes: b.rowBytes,
                                                                 dataType: b.dataType))
        solution.data.label = resultMatrixLabel
        
        let solver = MPSMatrixSolveCholesky(device: MetalSystem.shared.device,
                                            upper: true,
                                            order: order,
                                            numberOfRightHandSides: b.columns)
        
        solver.encode(commandBuffer: commandBuffer, 
                      sourceMatrix: decompositionResult,
                      rightHandSideMatrix: b,
                      solutionMatrix: solution)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
//        let status = decompositionStatus.contents().load(as: MPSMatrixDecompositionStatus.self)
//        switch status {
//        case .failure: print("decomp failed")
//        case .nonPositiveDefinite: print("non positive definite")
//        case .singular: print("singular")
//        case .success: print("decomp success")
//        @unknown default:
//            print("unknown status")
//        }
        
        return solution
    }
    
    static func solve(matrix: MPSMatrix, 
                      b: MPSMatrix,
                      resultMatrixLabel: String? = nil,
                      commandBufferLabel: String? = nil) -> MPSMatrix? {
        guard matrix.rows == b.rows else { return nil }
        guard matrix.rows == matrix.columns else { return nil }
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            return nil
        }
        commandBuffer.label = commandBufferLabel
        
        let order = matrix.rows
        
        let decomposedResultMatrix = MPSMatrix(device: MetalSystem.shared.device,
                                               descriptor: MPSMatrixDescriptor(rows: order,
                                                                               columns: order,
                                                                               rowBytes: order * 4,
                                                                               dataType: .float32))
        let pivotIndices = MPSMatrix(device: MetalSystem.shared.device,
                                     descriptor: MPSMatrixDescriptor(rows: 1,
                                                                     columns: order,
                                                                     rowBytes: order * 4,
                                                                     dataType: .uInt32))
        
        let decomposer = MPSMatrixDecompositionLU(device: MetalSystem.shared.device, rows: order, columns: order)
        let decompositionStatus = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<MPSMatrixDecompositionStatus>.size)!
        decomposer.encode(commandBuffer: commandBuffer,
                          sourceMatrix: matrix,
                          resultMatrix: decomposedResultMatrix,
                          pivotIndices: pivotIndices,
                          info: decompositionStatus)
        
        let solution = MPSMatrix(device: MetalSystem.shared.device,
                                 descriptor: MPSMatrixDescriptor(rows: order,
                                                                 columns: b.columns,
                                                                 rowBytes: b.columns * 4,
                                                                 dataType: .float32))
        solution.data.label = resultMatrixLabel

        let solver = MPSMatrixSolveLU(device: MetalSystem.shared.device,
                                      transpose: false,
                                      order: order,
                                      numberOfRightHandSides: b.columns)

        solver.encode(commandBuffer: commandBuffer,
//                      sourceMatrix: matrix,
                      sourceMatrix: decomposedResultMatrix,
                      rightHandSideMatrix: b,
                      pivotIndices: pivotIndices,
                      solutionMatrix: solution)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
//        let status = decompositionStatus.contents().load(as: MPSMatrixDecompositionStatus.self)
//        switch status {
//        case .failure: print("decomp failed")
//        case .nonPositiveDefinite: print("non positive definite")
//        case .singular: print("singular")
//        case .success: print("decomp success")
//        @unknown default:
//            print("unknown status")
//        }
        
        return solution
    }
    
    static func inverse(matrix: MPSMatrix,
                        resultMatrixLabel: String? = nil,
                        commandBufferLabel: String? = nil) -> MPSMatrix? {
        guard matrix.rows == matrix.columns else { return nil }
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            return nil
        }
        commandBuffer.label = commandBufferLabel
        
        let order = matrix.rows
        let decomposedResultMatrix = MPSMatrix(device: MetalSystem.shared.device,
                                               descriptor: MPSMatrixDescriptor(rows: order,
                                                                               columns: order,
                                                                               rowBytes: order * 4,
                                                                               dataType: .float32))
        let pivotIndices = MPSMatrix(device: MetalSystem.shared.device,
                                     descriptor: MPSMatrixDescriptor(rows: 1,
                                                                     columns: order,
                                                                     rowBytes: order * 4,
                                                                     dataType: .uInt32))
        
        let decomposer = MPSMatrixDecompositionLU(device: MetalSystem.shared.device, rows: order, columns: order)
        let decompositionStatus = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<MPSMatrixDecompositionStatus>.size)!
        decomposer.encode(commandBuffer: commandBuffer,
                          sourceMatrix: matrix,
                          resultMatrix: decomposedResultMatrix,
                          pivotIndices: pivotIndices,
                          info: decompositionStatus)
        var identityMatrixData = Array<Float>(repeating: 0, count: order * order)
        for i in 0..<order {
            identityMatrixData[i * order + i] = 1
        }
        guard let identityMatrixBuffer = MetalSystem.shared.device.makeBuffer(bytes: identityMatrixData, length: identityMatrixData.count * MemoryLayout<Float>.stride) else {
            print("Cannot create identity matrix buffer")
            return nil
        }
        let I = MPSMatrix(buffer: identityMatrixBuffer,
                          descriptor: MPSMatrixDescriptor(rows: order,
                                                          columns: order,
                                                          rowBytes: order * 4,
                                                          dataType: .float32))
        
        let solution = MPSMatrix(device: MetalSystem.shared.device,
                                 descriptor: MPSMatrixDescriptor(rows: order,
                                                                 columns: order,
                                                                 rowBytes: order * 4,
                                                                 dataType: .float32))
        solution.data.label = resultMatrixLabel
        
        let solver = MPSMatrixSolveLU(device: MetalSystem.shared.device,
                                      transpose: false,
                                      order: order,
                                      numberOfRightHandSides: order)
        
        solver.encode(commandBuffer: commandBuffer,
//                      sourceMatrix: matrix,
                      sourceMatrix: decomposedResultMatrix,
                      rightHandSideMatrix: I,
                      pivotIndices: pivotIndices,
                      solutionMatrix: solution)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
//        let status = decompositionStatus.contents().load(as: MPSMatrixDecompositionStatus.self)
//        switch status {
//        case .failure: print("decomp failed")
//        case .nonPositiveDefinite: print("non positive definite")
//        case .singular: print("singular")
//        case .success: print("decomp success")
//        @unknown default:
//            print("unknown status")
//        }
        
        return solution
    }
    
    static func inverse(spdMatrix matrix: MPSMatrix,
                        resultMatrixLabel: String? = nil,
                        commandBufferLabel: String? = nil) -> MPSMatrix? {
        guard matrix.rows == matrix.columns else { return nil }
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else {
            print("Cannot create command buffer")
            return nil
        }
        commandBuffer.label = commandBufferLabel
        
        let order = matrix.rows
        let decomposedResultMatrix = MPSMatrix(device: MetalSystem.shared.device,
                                               descriptor: MPSMatrixDescriptor(rows: order,
                                                                               columns: order,
                                                                               rowBytes: order * 4,
                                                                               dataType: .float32))
        let decomposer = MPSMatrixDecompositionCholesky(device: MetalSystem.shared.device, lower: false, order: order)
        let decompositionStatus = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<MPSMatrixDecompositionStatus>.size)!
        decomposer.encode(commandBuffer: commandBuffer,
                          sourceMatrix: matrix,
                          resultMatrix: decomposedResultMatrix,
                          status: decompositionStatus)
        var identityMatrixData = Array<Float>(repeating: 0, count: order * order)
        for i in 0..<order {
            identityMatrixData[i * order + i] = 1
        }
        guard let identityMatrixBuffer = MetalSystem.shared.device.makeBuffer(bytes: identityMatrixData, 
                                                                  length: identityMatrixData.count * MemoryLayout<Float>.stride) else {
            print("Cannot create identity matrix buffer")
            return nil
        }
        identityMatrixBuffer.label = "Identity Matrix"
        let I = MPSMatrix(buffer: identityMatrixBuffer,
                          descriptor: MPSMatrixDescriptor(rows: order,
                                                          columns: order,
                                                          rowBytes: order * 4,
                                                          dataType: .float32))
        
        let solution = MPSMatrix(device: MetalSystem.shared.device,
                                 descriptor: MPSMatrixDescriptor(rows: order,
                                                                 columns: order,
                                                                 rowBytes: order * 4,
                                                                 dataType: .float32))
        solution.data.label = resultMatrixLabel
        
        let solver = MPSMatrixSolveCholesky(device: MetalSystem.shared.device, 
                                            upper: true,
                                            order: order,
                                            numberOfRightHandSides: order)
        solver.encode(commandBuffer: commandBuffer,
                      sourceMatrix: decomposedResultMatrix,
                      rightHandSideMatrix: I,
                      solutionMatrix: solution)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
//        let status = decompositionStatus.contents().load(as: MPSMatrixDecompositionStatus.self)
//        switch status {
//        case .failure: print("decomp failed")
//        case .nonPositiveDefinite: print("non positive definite")
//        case .singular: print("singular")
//        case .success: print("decomp success")
//        @unknown default:
//            print("unknown status")
//        }
        
        return solution
    }
}
