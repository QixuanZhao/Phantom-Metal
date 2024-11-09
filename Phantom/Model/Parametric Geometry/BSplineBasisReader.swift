//
//  BSplineBasisReader.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/17.
//

import Metal

struct SpanSample: Identifiable {
    var id: Int { span.start.lastIndex }
    var span: BSplineBasis.KnotSpan
    var samples: [FunctionSample]
}

@Observable
class BSplineBasisReader {
    weak var basis: BSplineBasis?
    
    private(set) var samples: [SpanSample] = []
    private(set) var firstDerivativeSamples: [SpanSample] = []
    private(set) var secondDerivativeSamples: [SpanSample] = []
    private(set) var thirdDerivativeSamples: [SpanSample] = []
    
    var updated = false
    
    // load data
    func read() {
        guard let basis else { return }
        if updated { return }
        
        print("load data")
        samples.removeAll()
        firstDerivativeSamples.removeAll()
        secondDerivativeSamples.removeAll()
        thirdDerivativeSamples.removeAll()
        for (index, texture) in basis.basisTextures.enumerated() {
            if index >= basis.basisTextures.count { break }
            
            let interval = basis.knotSpans[index]
            let start = interval.start.knot.value
            let end = interval.end.knot.value
            let intervalLength = end - start
            let functionID = interval.start.lastIndex - basis.degree
            
            var spanSample: SpanSample = .init(span: interval, samples: [])
            var span1stDerivativeSample: SpanSample = .init(span: interval, samples: [])
            var span2ndDerivativeSample: SpanSample = .init(span: interval, samples: [])
            var span3rdDerivativeSample: SpanSample = .init(span: interval, samples: [])
            let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<Float>.size * texture.width * 4, alignment: 4)
            for k in 0..<basis.order {
                texture.getBytes(pointer,
                                 bytesPerRow: 0,
                                 bytesPerImage: texture.width * MemoryLayout<Float>.size * 4,
                                 from: MTLRegionMake1D(0, texture.width),
                                 mipmapLevel: 0,
                                 slice: k) // for i in 0..<order { slice = i }
                
                var functionSample: FunctionSample = .init(basisID: functionID + k, samples: [])
                var firstDerivativeSample: FunctionSample = .init(basisID: functionID + k, samples: [])
                var secondDerivativeSample: FunctionSample = .init(basisID: functionID + k, samples: [])
                var thirdDerivativeSample: FunctionSample = .init(basisID: functionID + k, samples: [])
                for i in 0..<texture.width {
                    let frac = Float(i) / Float(texture.width - 1)
                    let value = pointer.load(fromByteOffset: i * 16, as: Float.self)
                    let derivative = pointer.load(fromByteOffset: i * 16 + 4, as: Float.self)
                    let derivative2 = pointer.load(fromByteOffset: i * 16 + 8, as: Float.self)
                    let derivative3 = pointer.load(fromByteOffset: i * 16 + 12, as: Float.self)
                    let parameter = frac * intervalLength + start;
                    functionSample.samples.append((parameter, value))
                    firstDerivativeSample.samples.append((parameter, derivative))
                    secondDerivativeSample.samples.append((parameter, derivative2))
                    thirdDerivativeSample.samples.append((parameter, derivative3))
                }
                spanSample.samples.append(functionSample)
                span1stDerivativeSample.samples.append(firstDerivativeSample)
                span2ndDerivativeSample.samples.append(secondDerivativeSample)
                span3rdDerivativeSample.samples.append(thirdDerivativeSample)
            }
            samples.append(spanSample)
            firstDerivativeSamples.append(span1stDerivativeSample)
            secondDerivativeSamples.append(span2ndDerivativeSample)
            thirdDerivativeSamples.append(span3rdDerivativeSample)
            pointer.deallocate()
        }
        
        updated = true
    }
    
    init(basis: BSplineBasis? = nil) {
        self.basis = basis
    }
}
