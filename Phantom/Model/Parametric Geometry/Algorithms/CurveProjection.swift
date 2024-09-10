//
//  CurveProjection.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/3/1.
//

import Foundation

struct ProjectionResult {
    let parameters: SIMD2<Float>
    let point: SIMD3<Float>
    let projectedPoint: SIMD3<Float>
}

extension BSplineSurface {
    func project(_ curves: [BSplineCurve],
                 perCurveSampleCount: Int = 50,
                 parameterShift: Float = 0, // 0 ~ 1
                 startValueCandidates: [(SIMD2<Float>, SIMD3<Float>)] = [],
                 e1: Float = 1e-6,
                 e2: Float = 1e-6,
                 maxIteration: Int = 100) -> [ProjectionResult] {
        let candidates = if startValueCandidates.isEmpty { generateStartValueCandidates() } else { startValueCandidates }
        return curves.flatMap { curve in
            project(curve, sampleCount: perCurveSampleCount, parameterShift: parameterShift, startValueCandidates: candidates, e1: e1, e2: e2, maxIteration: maxIteration)
        }
    }
    
    func project(_ curve: BSplineCurve,
                 sampleCount: Int = 50,
                 parameterShift: Float = 0, // 0 ~ 1 -> [0, 1/50) (50 for sample count)
                 startValueCandidates: [(SIMD2<Float>, SIMD3<Float>)] = [],
                 e1: Float = 1e-6,
                 e2: Float = 1e-6,
                 maxIteration: Int = 100) -> [ProjectionResult] {
        let count = sampleCount
        let start = curve.basis.knots.first!.value
        let end = curve.basis.knots.last!.value
        
        let candidates = if startValueCandidates.isEmpty { generateStartValueCandidates() } else { startValueCandidates }
        
        let length = end - start
        let step = length / Float(count + 1)
        
        let shift = parameterShift * step
        
        var result: [ProjectionResult] = []
    
        for k in 1...count {
            let u = step * Float(k) + start + shift
            let point = curve.point(at: u)!
            let uv = self.inverse(point,
                                  startValueCandidates: candidates,
                                  e1: e1,
                                  e2: e2,
                                  maxIteration: maxIteration)
            let projectedPoint = self.point(at: uv)!
            result.append(ProjectionResult(parameters: uv, point: point, projectedPoint: projectedPoint))
        }
        
        return result
    }
}
