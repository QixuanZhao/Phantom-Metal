//
//  BernsteinBasis.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import Metal

class BernsteinBasis {
    var degree: Int {
        didSet {
            requireRecreateBasisTexture = true
        }
    }
    
    let reader: BernsteinBasisReader
    
    private(set) var requireRecreateBasisTexture = true
    
    private(set) var basisTextureDescriptor: MTLTextureDescriptor = {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .rg32Float
        descriptor.width = (Int(system.width) / 16) * 16
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.textureType = .type1DArray
        descriptor.arrayLength = 0
        descriptor.storageMode = .private
        return descriptor
    }()
    
    private(set) var argsBuffer: MTLBuffer!
    private(set) var knotBuffer: MTLBuffer!
    private(set) var basisTexture: MTLTexture!
    static private var computerState: MTLComputePipelineState = {
        try! system.device.makeComputePipelineState(function: system.library.makeFunction(name: "bernstein::computeBernsteinBasis")!)
    }()
    
    func recreateTexture () {
        if requireRecreateBasisTexture {
            basisTextureDescriptor.arrayLength = degree + 1
            self.basisTexture = system.device.makeTexture(descriptor: basisTextureDescriptor)!
            self.basisTexture.label = "Bernstein Basis"
            updateTexture()
            requireRecreateBasisTexture = false
        }
    }
    
    func updateTexture() {
        guard let buffer = system.commandQueue.makeCommandBuffer() else { return }
        if let encoder = buffer.makeComputeCommandEncoder() {
            let threadsPerThreadgroup = MTLSize(width: 16, height: 1, depth: 1)
            let threadgroupsPerGrid = MTLSize(width: Int(system.width) / 16, height: 1, depth: 1)
            
            encoder.setComputePipelineState(Self.computerState)
            encoder.setTexture(basisTexture, index: 0)
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            encoder.endEncoding()
        }
        buffer.commit()
    }
    
    init(degree: Int) {
        self.degree = degree
        self.reader = BernsteinBasisReader()
        self.reader.basis = self
        
        recreateTexture()
    }
}
