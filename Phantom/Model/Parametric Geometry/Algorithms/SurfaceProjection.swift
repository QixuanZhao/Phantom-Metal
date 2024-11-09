//
//  PointInversionOrProjection.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/29.
//

import simd
import MetalPerformanceShaders

extension BSplineCurve {
    func generateStartValueCandidates() -> [(Float, SIMD3<Float>)] {
        var candidates: [(Float, SIMD3<Float>)] = []
        
        let domain = basis.knots.last!.value - basis.knots.first!.value
        
        for span in basis.knotSpans {
            let start = span.start.knot.value
            let end = span.end.knot.value
            let length = end - start
            let n = max(Int(length / domain * 50), 1)
            let step = length / Float(n)
            for k in 0..<n {
                let value = step * Float(k) + start
                candidates.append((value, self.point(at: value)!))
            }
        }
        
        candidates.append((basis.knots.last!.value, self.point(at: basis.knots.last!.value)!))
        
        return candidates
    }
    
    func startValueForInvsersion(_ point: SIMD3<Float>,
                                 candidates: [(Float, SIMD3<Float>)] = []) -> Float {
        let parameterCandidates = if candidates.isEmpty {
            generateStartValueCandidates()
        } else { candidates }
        
        return parameterCandidates.map { ($0.0, distance($0.1, point)) }.sorted { $0.1 < $1.1 }.first!.0
    }
    
    func inverse(_ point: SIMD3<Float>,
                 u0: Float,
                 span: ClosedRange<Float>? = nil,
                 e1: Float = 1e-6,
                 e2: Float = 1e-6,
                 maxIteration: Int = 100) -> Float {
        var iteration = 0
        var ui = u0
        
        let interval = span ?? (self.basis.knots.first!.value ... self.basis.knots.last!.value)
        
        while true {
            let C = self.point(at: ui)!
            let offset = C - point
            
            let potentialTangent = self.points(at: ui, derivativeOrder: 1)
            let tangentIndex = if abs(dot(normalize(potentialTangent.first!), offset)) > abs(dot(normalize(potentialTangent.last!), offset)) {
                1
            } else { 0 }
            
            let tangent = potentialTangent[tangentIndex]
            
            let curvature = self.points(at: ui, derivativeOrder: 2)[tangentIndex]
            let velocity2 = length_squared(tangent)
            
            let offsetLength = length(offset)
            let cosine = abs(dot(offset, tangent) / (length(offset) * length(tangent)))
            let pointCoincident = offsetLength < e1
            let cosineIsZero = cosine < e2
            if pointCoincident && cosineIsZero {
                return ui
            }
            
            let uj = ui // uj = u_{i-1}
            ui = ui - dot(tangent, offset) / (dot(curvature, offset) + velocity2)
            iteration = iteration + 1
            
            if ui < interval.lowerBound { ui = interval.lowerBound }
            if ui > interval.upperBound { ui = interval.upperBound }
            
            if ui.isNaN {
                print("Reached nan")
                return uj
            }
            
            if length(tangent * (ui - uj)) < e1 || pointCoincident || cosineIsZero {
                return ui
            }
            
            if iteration >= maxIteration {
                print("max iteration")
                return ui
            }
        }
    }
    
    func inverse(_ point: SIMD3<Float>,
                 startValueCandidates: [(Float, SIMD3<Float>)] = [],
                 e1: Float = 1e-6,
                 e2: Float = 1e-6,
                 maxIteration: Int = 100) -> Float {
        let u0 = startValueForInvsersion(point, candidates: startValueCandidates)
        let span = basis.containingKnotSpans(of: u0).first!
        
        return inverse(point, u0: u0, span: span.start.knot.value ... span.end.knot.value,
                       e1: e1, e2: e2, maxIteration: maxIteration)
    }
}

extension BSplineSurface {
    func generateStartValueCandidates() -> [(SIMD2<Float>, SIMD3<Float>)] {
        var uCandidates: [Float] = []
        var vCandidates: [Float] = []
        
//        let uDomain = uBasis.knots.last!.value - uBasis.knots.first!.value
//        let vDomain = vBasis.knots.last!.value - vBasis.knots.first!.value
        
        for uSpan in uBasis.knotSpans {
            let start = uSpan.start.knot.value
            let end = uSpan.end.knot.value
            let length = end - start
//            let n = max(Int(length / uDomain * 50), 1)
            let n = (uBasis.degree + 2) * 2
            let step = length / Float(n)
            for k in 0..<n {
                let value = step * Float(k) + start
                uCandidates.append(value)
            }
        }
        uCandidates.append(uBasis.knots.last!.value)
        
        for vSpan in vBasis.knotSpans {
            let start = vSpan.start.knot.value
            let end = vSpan.end.knot.value
            let length = end - start
//            let n = max(Int(length / vDomain * 50), 1)
            let n = (vBasis.degree + 2) * 2
            let step = length / Float(n)
            for k in 0..<n {
                let value = step * Float(k) + start
                vCandidates.append(value)
            }
        }
        vCandidates.append(vBasis.knots.last!.value)
        
        var candidates: [(SIMD2<Float>, SIMD3<Float>)] = []
        for u in uCandidates {
            for v in vCandidates {
                candidates.append(([u, v], self.point(at: [u, v])!))
            }
        }
        
        return candidates
    }
    
    func startValueForInvsersion(_ point: SIMD3<Float>, candidates: [(SIMD2<Float>, SIMD3<Float>)] = []) -> SIMD2<Float> {
        let parameterCandidates = if candidates.isEmpty {
            generateStartValueCandidates()
        } else { candidates }
        
        return parameterCandidates.map { ($0.0, distance($0.1, point)) }.sorted { $0.1 < $1.1 }.first!.0
    }
    
    func inverse(_ point: SIMD3<Float>,
                 uv0: SIMD2<Float>,
                 spanU: ClosedRange<Float>? = nil,
                 spanV: ClosedRange<Float>? = nil,
                 e1: Float = 1e-6,
                 e2: Float = 1e-6,
                 maxIteration: Int = 100) -> SIMD2<Float> {
        var uvi = uv0
        
        let intervalU = spanU ?? (self.uBasis.knots.first!.value ... self.uBasis.knots.last!.value)
        let intervalV = spanV ?? (self.vBasis.knots.first!.value ... self.vBasis.knots.last!.value)
        
        for _ in 0..<maxIteration {
            let offset = self.point(at: uvi)! - point
            
            let potentialTangentU = self.points(at: uvi, derivativeOrder: (1, 0)).flatMap { $0 }
            let tangentUIndex = if abs(dot(normalize(potentialTangentU.first!), offset)) > abs(dot(normalize(potentialTangentU.last!), offset)) {
                1
            } else { 0 }
            
            let tangentU = potentialTangentU[tangentUIndex]
            
            let potentialTangentV = self.points(at: uvi, derivativeOrder: (0, 1)).flatMap { $0 }
            let tangentVIndex = if abs(dot(normalize(potentialTangentV.first!), offset)) > abs(dot(normalize(potentialTangentV.last!), offset)) {
                1
            } else { 0 }
            
            let tangentV = potentialTangentV[tangentVIndex]
            
            let derivativeUU = self.points(at: uvi, derivativeOrder: (2, 0))[tangentUIndex].first!
            let derivativeVV = self.points(at: uvi, derivativeOrder: (0, 2)).first![tangentVIndex]
            let derivativeUV = self.points(at: uvi, derivativeOrder: (1, 1))[tangentUIndex][tangentVIndex]
            
            let velocityU2 = length_squared(tangentU)
            let velocityV2 = length_squared(tangentV)
            
            let offsetLength = length(offset)
            let cosineU = abs(dot(tangentU, offset) / (length(tangentU) * offsetLength))
            let cosineV = abs(dot(tangentV, offset) / (length(tangentV) * offsetLength))
            let pointCoincident = offsetLength < e1
            let cosineIsZero = cosineU < e2 && cosineV < e2
            if pointCoincident && cosineIsZero {
                return uvi
            }
            
            let uvj = uvi // uj = u_{i-1}
            let a = velocityU2 + dot(offset, derivativeUU)
            let b = dot(tangentU, tangentV) + dot(offset, derivativeUV)
            let c = velocityV2 + dot(offset, derivativeVV)
            let n = -dot(offset, tangentU)
            let m = -dot(offset, tangentV)
            
            let denom = b * b - a * c
            let deltaU = (b * m - c * n) / denom
            let deltaV = (b * n - a * m) / denom
            uvi = uvi + SIMD2<Float>(x: deltaU, y: deltaV)
            
            uvi = clamp(uvi, min: [intervalU.lowerBound, intervalV.lowerBound], max: [intervalU.upperBound, intervalV.upperBound])
            
//            if length(tangentU * (uvi.x - uvj.x) + tangentV * (uvi.y - uvj.y)) < e1 || pointCoincident || cosineIsZero {
//                return uvi 73
//            }
            
            if length(tangentU * (uvi.x - uvj.x) + tangentV * (uvi.y - uvj.y)) < e1 {
                return uvi
            }
            
            if pointCoincident || cosineIsZero {
                return uvi
            }
        }
        
        print("max iteration")
        return uvi
    }
    
//    func inverse(_ point: SIMD3<Float>,
//                 e1: Float = 1e-6,
//                 e2: Float = 1e-6,
//                 maxIteration: Int = 100) -> SIMD2<Float> {
//        let uv0 = startValueForInvsersion(point)
//        let uSpanStart = uBasis.containingKnotSpans(of: uv0[0]).first!.start.knot.value
//        let vSpanStart = vBasis.containingKnotSpans(of: uv0[1]).first!.start.knot.value
//        let uSpanEnd = uBasis.containingKnotSpans(of: uv0[0]).last!.end.knot.value
//        let vSpanEnd = vBasis.containingKnotSpans(of: uv0[1]).last!.end.knot.value
//        
//        return inverse(point, uv0: uv0,
//                       spanU: uSpanStart ... uSpanEnd,
//                       spanV: vSpanStart ... vSpanEnd,
//                       e1: e1, e2: e2,
//                       maxIteration: maxIteration)
//    }
    
    func inverse(_ point: SIMD3<Float>,
                 startValueCandidates: [(SIMD2<Float>, SIMD3<Float>)] = [],
                 e1: Float = 1e-6,
                 e2: Float = 1e-6,
                 maxIteration: Int = 100) -> SIMD2<Float> {
        let uv0 = startValueForInvsersion(point, candidates: startValueCandidates)
        let uSpanStart = uBasis.containingKnotSpans(of: uv0[0]).first!.start.knot.value
        let vSpanStart = vBasis.containingKnotSpans(of: uv0[1]).first!.start.knot.value
        let uSpanEnd = uBasis.containingKnotSpans(of: uv0[0]).last!.end.knot.value
        let vSpanEnd = vBasis.containingKnotSpans(of: uv0[1]).last!.end.knot.value
        
        return inverse(point, uv0: uv0,
                       spanU: uSpanStart ... uSpanEnd,
                       spanV: vSpanStart ... vSpanEnd,
                       e1: e1, e2: e2,
                       maxIteration: maxIteration)
    }
    
    func inverse(_ points: [SIMD3<Float>],
                 startValueCandidates: [(SIMD2<Float>, SIMD3<Float>)] = [],
                 e1: Float = 1e-6,
                 e2: Float = 1e-6,
                 maxIteration: Int = 100) -> [SIMD2<Float>] {
        return points.map { point in
            let uv0 = startValueForInvsersion(point, candidates: startValueCandidates)
            let uSpanStart = uBasis.containingKnotSpans(of: uv0[0]).first!.start.knot.value
            let vSpanStart = vBasis.containingKnotSpans(of: uv0[1]).first!.start.knot.value
            let uSpanEnd = uBasis.containingKnotSpans(of: uv0[0]).last!.end.knot.value
            let vSpanEnd = vBasis.containingKnotSpans(of: uv0[1]).last!.end.knot.value
            return inverse(point, uv0: uv0,
                           spanU: uSpanStart ... uSpanEnd,
                           spanV: vSpanStart ... vSpanEnd,
                           e1: e1, e2: e2,
                           maxIteration: maxIteration)
        }
    }
}
