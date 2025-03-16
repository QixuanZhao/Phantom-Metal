//
//  BernsteinBasisReader.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import Metal

struct FunctionSample: Identifiable {
    var id: Int { basisID }
    var basisID: Int
    var samples: [(Float, Float)]
}

@MainActor
@Observable
class BernsteinBasisReader: Sendable {
    weak var basis: BernsteinBasis?
    
    private(set) var samples: [FunctionSample] = []
    private(set) var derivativeSamples: [FunctionSample] = []
    
    var updated = false
    
    func read() {
        guard let basis else { return }
        if updated { return }
        
        samples.removeAll()
        derivativeSamples.removeAll()
        
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<Float>.size * basis.basisTexture.width * 2, alignment: 4)
        for k in 0...basis.degree {
            basis.basisTexture.getBytes(pointer,
                             bytesPerRow: 0,
                             bytesPerImage: basis.basisTexture.width * MemoryLayout<Float>.size * 2,
                             from: MTLRegionMake1D(0, basis.basisTexture.width),
                             mipmapLevel: 0,
                             slice: k)
            
            var functionSample: FunctionSample = .init(basisID: k, samples: [])
            var derivativeSample: FunctionSample = .init(basisID: k, samples: [])
            for i in 0..<basis.basisTexture.width {
                let parameter = Float(i) / Float(basis.basisTexture.width - 1)
                let value = pointer.load(fromByteOffset: i * 8, as: Float.self)
                let derivative = pointer.load(fromByteOffset: i * 8 + 4, as: Float.self)
                functionSample.samples.append((parameter, value))
                derivativeSample.samples.append((parameter, derivative))
            }
            samples.append(functionSample)
            derivativeSamples.append(derivativeSample)
        }
        pointer.deallocate()
        
        updated = true
    }
    
    init(basis: BernsteinBasis? = nil) {
        self.basis = basis
    }
}
