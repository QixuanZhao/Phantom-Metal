//
//  BSplineBasis.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/6.
//

import Metal

@MainActor
@Observable
class BSplineBasis: Sendable {
    var degree: Int {
        didSet {
            if degree < 0 { degree = oldValue }
            else {
                requireRecreateBasisTexture = true
                requireUpdateBasis = true
            }
        }
    }
    var order: Int { get { degree + 1 } set { degree = newValue - 1 } }
    
    var basisCount: Int { knotVector.count - order }
    
    let reader: BSplineBasisReader
    
    private(set) var requireUpdateKnot = true
    private(set) var requireUpdateBasis = true
    private(set) var requireRecreateBasisTexture = false
    
    private(set) var basisTextureDescriptor: MTLTextureDescriptor = {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .rgba32Float
        descriptor.width = (Int(MetalSystem.shared.width) / 16) * 16
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.textureType = .type1DArray
        descriptor.arrayLength = 0
        descriptor.storageMode = .shared
        return descriptor
    }()
    
    struct Knot {
        var value: Float
        var multiplicity: Int
    }
    
    struct IndexedKnot {
        var knot: Knot
        var firstIndex: Int
        var lastIndex: Int {
            get { firstIndex + knot.multiplicity - 1 }
            set { firstIndex = newValue + 1 - knot.multiplicity }
        }
    }
    
    struct KnotSpan {
        var start: IndexedKnot // start knot
        var end: IndexedKnot // end knot
    }
    
    var knots: [Knot] {
        didSet {
            if knots.count != oldValue.count { requireRecreateBasisTexture = true }
            requireUpdateKnot = true
            requireUpdateBasis = true
        }
    }
    
    var multiplicitySum: Int {
        var sum = 0
        knots.forEach { knot in
            sum = sum + knot.multiplicity
        }
        return sum
    }
    
    var controlPointCount: Int { multiplicitySum - order }
    
    var indexedKnots: [IndexedKnot] {
        var index = 0
        var result: [IndexedKnot] = []
        
        for knot in knots {
            let indexedKnot = IndexedKnot(knot: knot, firstIndex: index)
            result.append(indexedKnot)
            index = indexedKnot.lastIndex + 1
        }
        return result
    }
    
    var knotVector: [Float] {
        knots.flatMap {
            Array(repeating: $0.value, count: $0.multiplicity)
        }
    }
    
    var knotSpans: [KnotSpan] {
        var result: [KnotSpan] = []
        if knots.count < 2 { return [] }
        
        let ik = indexedKnots
        for i in 1..<ik.count {
            result.append(KnotSpan(start: ik[i - 1], end: ik[i]))
        }
        
        return result
    }
    
    private(set) var argsBuffer: MTLBuffer!
    private(set) var knotBuffer: MTLBuffer!
    private(set) var basisTextures: [MTLTexture] = []
    static private(set) var computerState: MTLComputePipelineState = {
        try! MetalSystem.shared.device.makeComputePipelineState(function: MetalSystem.shared.library.makeFunction(name: "spline::computeBSplineBasis")!)
    }()
    
    static private(set) var basisCalculatorState: MTLComputePipelineState = {
        try! MetalSystem.shared.device.makeComputePipelineState(function: MetalSystem.shared.library.makeFunction(name: "spline::basisAt")!)
    }()
    
    static private(set) var derivative1CalculatorState: MTLComputePipelineState = {
        try! MetalSystem.shared.device.makeComputePipelineState(function: MetalSystem.shared.library.makeFunction(name: "spline::firstDerivativeAt")!)
    }()
    
    static private(set) var derivative2CalculatorState: MTLComputePipelineState = {
        try! MetalSystem.shared.device.makeComputePipelineState(function: MetalSystem.shared.library.makeFunction(name: "spline::secondDerivativeAt")!)
    }()
    
    static private(set) var derivative3CalculatorState: MTLComputePipelineState = {
        try! MetalSystem.shared.device.makeComputePipelineState(function: MetalSystem.shared.library.makeFunction(name: "spline::thirdDerivativeAt")!)
    }()
    
    func multiplicity(of value: Float) -> Int {
        if let firstIndex = knots.firstIndex(where: { $0.value == value }) {
            knots[firstIndex].multiplicity
        } else { 0 }
    }
    
    func multiplicity(at vectorIndex: Int) -> Int {
        if let firstIndex = indexedKnots.firstIndex(where: { $0.firstIndex <= vectorIndex && vectorIndex <= $0.lastIndex }) {
            indexedKnots[firstIndex].knot.multiplicity
        } else { 0 }
    }
    
    func updateKnotBuffer() {
        if requireUpdateKnot {
            knotBuffer = MetalSystem.shared.device.makeBuffer(bytes: knotVector, length: MemoryLayout<Float>.stride * knotVector.count)
            requireUpdateKnot = false
        }
    }
    
    private func recreateTexture () {
        if requireRecreateBasisTexture {
            self.basisTextures = []
            basisTextureDescriptor.arrayLength = order
            for i in 1..<knots.count {
                let texture = MetalSystem.shared.device.makeTexture(descriptor: basisTextureDescriptor)!
                texture.label = "B-Spline Basis \(knots[i - 1].value), \(knots[i].value)"
                self.basisTextures.append(texture)
            }
            requireRecreateBasisTexture = false
        }
    }
    
    func updateTexture() {
        if requireUpdateBasis {
            recreateTexture()
            guard let buffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else { return }
            if let splineEncoder = buffer.makeComputeCommandEncoder() {
                encodeTextureUpdate(splineEncoder)
                splineEncoder.endEncoding()
            }
            buffer.commit()
            buffer.waitUntilCompleted()
            self.reader.updated = false
        }
    }
    
    private func encodeTextureUpdate(_ encoder: MTLComputeCommandEncoder) {
        if requireUpdateBasis {
            updateKnotBuffer()
            
            let args = BSplineKernelArgument(degree: Int32(degree),
                                             knotCount: Int32(multiplicitySum))
            
            argsBuffer.contents().storeBytes(of: args, as: BSplineKernelArgument.self)
            
            encoder.setComputePipelineState(Self.computerState)
            encoder.setBuffer(argsBuffer, offset: 0, index: 0)
            encoder.setBuffer(knotBuffer, offset: 0, index: 1)
            
            let threadsPerThreadgroup = MTLSize(width: 16, height: 1, depth: 1)
            let threadgroupsPerGrid = MTLSize(width: Int(MetalSystem.shared.width) / 16, height: 1, depth: 1)
            
            for index in 0 ..< knotSpans.count {
                let interval = knotSpans[index]
                encoder.setBytes([interval.start.lastIndex], length: MemoryLayout<Int>.size, index: 2)
                encoder.setTexture(basisTextures[index], index: 0)
                encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            }
            requireUpdateBasis = false
        }
    }
    
    init(degree: Int = 3,
         knots: [Knot] = [
            Knot(value: 0, multiplicity: 4),
            Knot(value: 0.25, multiplicity: 3),
            Knot(value: 0.5, multiplicity: 2),
            Knot(value: 0.75, multiplicity: 1),
            Knot(value: 1, multiplicity: 4)
         ]
    ) {
        self.degree = degree
        self.knots = knots
        self.reader = BSplineBasisReader()
        self.reader.basis = self
        
        self.argsBuffer = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<BSplineKernelArgument>.size, options: .storageModeShared)
        self.knotBuffer = MetalSystem.shared.device.makeBuffer(bytes: knotVector, length: MemoryLayout<Float>.stride * knots.count, options: .storageModeShared)
        self.basisTextureDescriptor.arrayLength = order
        
        for i in 1..<knots.count {
            let texture = MetalSystem.shared.device.makeTexture(descriptor: basisTextureDescriptor)!
            texture.label = "B-Spline Basis \(knots[i - 1].value), \(knots[i].value)"
            self.basisTextures.append(texture)
        }
        
        updateTexture()
    }
}
