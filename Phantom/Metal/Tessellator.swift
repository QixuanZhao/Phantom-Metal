//
//  Tessellator.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/16.
//

import Metal

class Tessellator {
    static var factorComputeState: MTLComputePipelineState = {
        try! system.device.makeComputePipelineState(function: system.library.makeFunction(name: "tessellation::computeTessellationFactors")!)
    }()
    
    static func fillFactors(buffer: MTLBuffer,
                                        edgeFactors: SIMD4<Float>,
                                        insideFactors: SIMD2<Float>,
                                        completeHandler: @escaping () -> Void = { }) {
        if let commandBuffer = system.commandQueue.makeCommandBuffer() {
            if let encoder = commandBuffer.makeComputeCommandEncoder() {
                encoder.setComputePipelineState(factorComputeState)
                encoder.setBuffer(buffer, offset: 0, index: 0)
                encoder.setBytes([edgeFactors], length: MemoryLayout<SIMD4<Float>>.size, index: 1)
                encoder.setBytes([insideFactors], length: MemoryLayout<SIMD2<Float>>.size, index: 2)
                encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1),
                                             threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
                encoder.endEncoding()
                commandBuffer.addCompletedHandler { _ in completeHandler() }
            }
            commandBuffer.commit()
        }
    }
}
