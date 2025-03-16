//
//  FloatingPoint+Sampler.swift
//  Phantom
//
//  Created by TSAR Weasley on 2025/3/16.
//

import Foundation

extension BinaryFloatingPoint {
    static func sample(
        in range: Range<Self>,
        count: Int,
        inclusive: Bool = false
    ) -> [Self] {
        guard count > 0 else { return [] }
        
        let rangeLength = range.upperBound - range.lowerBound
        let step = rangeLength / Self.init(inclusive ? count : count + 1)
        let start = inclusive ? range.lowerBound : range.lowerBound + step
        
        return (0..<count).map { k in
            start + Self.init(k) * step
        }
    }
    
    static func sample(
        in range: ClosedRange<Self>,
        count: Int,
        inclusive: Bool = false
    ) -> [Self] {
        guard count > 0 else { return [] }
        
        let rangeLength = range.upperBound - range.lowerBound
        let step = rangeLength / Self.init(inclusive ? count - 1 : count)
        let start = inclusive ? range.lowerBound : range.lowerBound + step
        
        return (0..<count).map { k in
            start + Self.init(k) * step
        }
    }
}
