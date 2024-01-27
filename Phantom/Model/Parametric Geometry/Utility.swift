//
//  Util.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/4.
//

import Metal

extension BSplineBasis {
    func evaluate(_ u: Float) -> (Int, [Float]) {
        let firstIndex = knots.firstIndex(where: { $0.value > u })!
        let indexedKnots = indexedKnots
        let upperBound = indexedKnots[firstIndex].firstIndex
        let baseIndex = upperBound - order
        
        guard let buffer = system.device.makeBuffer(length: MemoryLayout<Float>.stride * order) else { return (-1, []) }
        guard let commandBuffer = system.commandQueue.makeCommandBuffer() else { return (-1, []) }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return (-1, []) }
        encoder.setComputePipelineState(Self.calculatorState)
        let argument = BSplineKernelArgument(degree: Int32(degree), knotCount: Int32(multiplicitySum))
        encoder.setBytes([argument], length: MemoryLayout.size(ofValue: argument), index: 0)
        encoder.setBuffer(knotBuffer, offset: 0, index: 1)
        encoder.setBytes([Int32(upperBound - 1)], length: MemoryLayout<Int32>.size, index: 2)
        encoder.setBytes([u], length: MemoryLayout<Float>.size, index: 3)
        encoder.setBuffer(buffer, offset: 0, index: 4)
        encoder.dispatchThreads(.init(width: 1, height: 1, depth: 1), threadsPerThreadgroup: .init(width: 1, height: 1, depth: 1))
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let pointer = buffer.contents()
        var N: [Float] = []
        for i in 0...degree {
            let value = pointer.load(fromByteOffset: i * MemoryLayout<Float>.stride, as: Float.self)
            N.append(value)
        }
        
        return (baseIndex, N)
    }
    
    func evaluate(i: Int, _ u: Float) -> Float {
        let firstIndex = knots.firstIndex(where: { $0.value > u })!
        let indexedKnots = indexedKnots
        let upperBound = indexedKnots[firstIndex].firstIndex
        let baseIndex = upperBound - order
        if i < baseIndex || i >= upperBound { return 0 }
        
        let result = evaluate(u)
        let N = result.1
        return N[i - baseIndex]
        
//        [[kernel]] void basisAt(constant BSplineKernelArgument& args [[buffer(0)]],
//                                constant float * knots [[buffer(1)]], // length = (degree + 1) * 2
//                                constant int& intervalId [[buffer(2)]],
//                                constant float& u [[buffer(3)]],
//                                device float * result [[buffer(4)]]) {
    }
}

extension BSplineCurve {
    static func intersect(_ curve1: BSplineCurve, _ curve2: BSplineCurve) -> (Float, Float)? {
        var c1 = BSplineCurve(knots: curve1.basis.knots,
                              controlPoints: curve1.controlPoints,
                              degree: curve1.basis.degree)
        
        var c2 = BSplineCurve(knots: curve2.basis.knots,
                              controlPoints: curve2.controlPoints,
                              degree: curve2.basis.degree)
        
        var start1 = c1.basis.knots.first!.value
        var end1 = c1.basis.knots.last!.value
        
        var start2 = c2.basis.knots.first!.value
        var end2 = c2.basis.knots.last!.value
        
        if c1.controlPoints.first! == c2.controlPoints.first! {
            return (start1, start2)
        } else if c1.controlPoints.first! == c2.controlPoints.last! {
            return (start1, end2)
        } else if c1.controlPoints.last! == c2.controlPoints.first! {
            return (end1, start2)
        } else if c1.controlPoints.last! == c2.controlPoints.last! {
            return (end1, end2)
        }
        
        var boundingBox1 = c1.boundingBox
        var boundingBox2 = c2.boundingBox
        var overlap = boundingBox1 * boundingBox2
        
        while overlap != nil {
            
        }
        
        return nil
    }
}
