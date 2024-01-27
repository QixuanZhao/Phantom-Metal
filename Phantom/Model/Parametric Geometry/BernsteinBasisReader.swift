//
//  BernsteinBasisReader.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import Metal

class BernsteinBasisReader {
    weak var basis: BernsteinBasis?
    
    private(set) var samples: [FunctionSample] = []
    private(set) var derivativeSamples: [FunctionSample] = []
    
    private var blitTexture: MTLTexture!
    private var currentTextureDegree: Int = 0
    
    private(set) var busy = false
    
    struct FunctionSample: Identifiable {
        var id: Int { basisID }
        var basisID: Int
        var samples: [(Float, Float)]
    }
    
    private func createTexture() {
        guard let basis else { return }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .rg32Float
        descriptor.width = (Int(system.width) / 16) * 16
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.textureType = .type1DArray
        descriptor.arrayLength = basis.degree + 1
        descriptor.storageMode = .shared
        
        currentTextureDegree = basis.degree
        blitTexture = system.device.makeTexture(descriptor: descriptor)!
    }
    
    private func blit(onComplete handler: @escaping () -> Void = { }) {
        guard let basis else { return }
        
        if let buffer = system.commandQueue.makeCommandBuffer() {
            if let encoder = buffer.makeBlitCommandEncoder() {
                encoder.copy(from: basis.basisTexture, to: blitTexture)
                encoder.endEncoding()
            }
            buffer.addCompletedHandler { _ in
                handler()
            }
            buffer.commit()
        }
    }
    
    private var load: () -> Void = {}
    
    func loadData(onComplete handler: @escaping () -> Void = {}) {
        guard let basis else { return }
        
        busy = true
        if currentTextureDegree != basis.degree {
            createTexture()
        }
        
        blit { [weak self] in
            self?.load()
            self?.busy = false
            handler()
        }
    }
    
    init(basis: BernsteinBasis? = nil) {
        self.basis = basis
        self.load = { [weak self] in
            guard let self else { return }
            guard let basis = self.basis else { return }
            
            samples.removeAll()
            derivativeSamples.removeAll()
            
            guard let texture = blitTexture else { return }
            
            let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<Float>.size * texture.width * 2, alignment: 4)
            for k in 0...basis.degree {
                texture.getBytes(pointer,
                                 bytesPerRow: 0,
                                 bytesPerImage: texture.width * MemoryLayout<Float>.size * 2,
                                 from: MTLRegionMake1D(0, texture.width),
                                 mipmapLevel: 0,
                                 slice: k)
                
                var functionSample: FunctionSample = .init(basisID: k, samples: [])
                var derivativeSample: FunctionSample = .init(basisID: k, samples: [])
                for i in 0..<texture.width {
                    let parameter = Float(i) / Float(texture.width - 1)
                    let value = pointer.load(fromByteOffset: i * 8, as: Float.self)
                    let derivative = pointer.load(fromByteOffset: i * 8 + 4, as: Float.self)
                    functionSample.samples.append((parameter, value))
                    derivativeSample.samples.append((parameter, derivative))
                }
                samples.append(functionSample)
                derivativeSamples.append(derivativeSample)
            }
            pointer.deallocate()
        }
    }
}
