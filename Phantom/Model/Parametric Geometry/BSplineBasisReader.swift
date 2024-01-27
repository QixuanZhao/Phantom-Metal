//
//  BSplineBasisReader.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/17.
//

import Metal

@Observable
class BSplineBasisReader {
    weak var basis: BSplineBasis?
    
    private(set) var samples: [IntervalSample] = []
    private(set) var derivativeSamples: [IntervalSample] = []
    
    private var blitTextures: [MTLTexture] = []
    private var currentTextureOrder: Int = 0
    
    private(set) var busy = false
    
//    var requireUpdate = false
    
    struct IntervalSample: Identifiable {
        var id: Int { interval.start.lastIndex }
        var interval: BSplineBasis.KnotSpan
        var samples: [FunctionSample]
    }
    
    struct FunctionSample: Identifiable {
        var id: Int { basisID }
        var basisID: Int
        var samples: [(Float, Float)]
    }
    
    private func createTextures() {
        guard let basis else { return }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .rg32Float
        descriptor.width = (Int(system.width) / 16) * 16
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.textureType = .type1DArray
        descriptor.arrayLength = basis.order
        descriptor.storageMode = .shared
        
        currentTextureOrder = basis.order
        
        blitTextures.removeAll()
        for _ in 1..<basis.knots.count {
            blitTextures.append(system.device.makeTexture(descriptor: descriptor)!)
        }
    }
    
    private func blit(onComplete handler: @escaping () -> Void = { }) {
        guard let basis else { return }
        
        if let buffer = system.commandQueue.makeCommandBuffer() {
            if let encoder = buffer.makeBlitCommandEncoder() {
                for i in 0..<basis.basisTextures.count {
                    encoder.copy(from: basis.basisTextures[i], to: blitTextures[i])
                }
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
        if basis.knots.count - 1 != blitTextures.count || currentTextureOrder != basis.order {
            createTextures()
        }
        
        blit { [weak self] in
            self?.load()
            self?.busy = false
            handler()
        }
    }
    
    init(basis: BSplineBasis? = nil) {
        self.basis = basis
        self.load = { [weak self] in
            guard let self else { return }
            guard let basis = self.basis else { return }
            
            samples.removeAll()
            derivativeSamples.removeAll()
            for (index, texture) in blitTextures.enumerated() {
                let interval = basis.knotSpans[index]
                let start = interval.start.knot.value
                let end = interval.end.knot.value
                let intervalLength = end - start
                let functionID = interval.start.lastIndex - basis.degree
                
                var intervalSample: IntervalSample = .init(interval: interval, samples: [])
                var intervalDerivativeSample: IntervalSample = .init(interval: interval, samples: [])
                let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<Float>.size * texture.width * 2, alignment: 4)
                for k in 0..<basis.order {
                    texture.getBytes(pointer,
                                     bytesPerRow: 0,
                                     bytesPerImage: texture.width * MemoryLayout<Float>.size * 2,
                                     from: MTLRegionMake1D(0, texture.width),
                                     mipmapLevel: 0,
                                     slice: k) // for i in 0..<order { slice = i }
                    
                    var functionSample: FunctionSample = .init(basisID: functionID + k, samples: [])
                    var derivativeSample: FunctionSample = .init(basisID: functionID + k, samples: [])
                    for i in 0..<texture.width {
                        let frac = Float(i) / Float(texture.width - 1)
                        let value = pointer.load(fromByteOffset: i * 8, as: Float.self)
                        let derivative = pointer.load(fromByteOffset: i * 8 + 4, as: Float.self)
                        let parameter = frac * intervalLength + start;
                        functionSample.samples.append((parameter, value))
                        derivativeSample.samples.append((parameter, derivative))
                    }
                    intervalSample.samples.append(functionSample)
                    intervalDerivativeSample.samples.append(derivativeSample)
                }
                samples.append(intervalSample)
                derivativeSamples.append(intervalDerivativeSample)
                pointer.deallocate()
            }
        }
    }
}
