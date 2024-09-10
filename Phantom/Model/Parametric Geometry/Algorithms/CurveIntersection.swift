//
//  CurveIntersection.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/3/2.
//

import simd

extension BSplineCurve {
    static func startValueForProjection(_ curveA: BSplineCurve,
                                        _ curveB: BSplineCurve,
                                        candidatesA: [(Float, SIMD3<Float>)] = [],
                                        candidatesB: [(Float, SIMD3<Float>)] = []) -> (Float, Float) {
        let finalCandidatesA = if candidatesA.isEmpty { curveA.generateStartValueCandidates() } else { candidatesA }
        let finalCandidatesB = if candidatesB.isEmpty { curveB.generateStartValueCandidates() } else { candidatesB }
        
        var candidate: (Float, Float) = (finalCandidatesA.first!.0, finalCandidatesB.first!.0)
        var candidateDistanceSquared: Float = distance_squared(finalCandidatesA.first!.1, finalCandidatesB.first!.1)
        
        for a in finalCandidatesA {
            for b in finalCandidatesB {
                let d = distance_squared(a.1, b.1)
                if d < candidateDistanceSquared {
                    candidateDistanceSquared = d
                    candidate = (a.0, b.0)
                }
            }
        }
        
        return candidate
    }
    
    static func nearestParameter(_ curveA: BSplineCurve,
                                 _ curveB: BSplineCurve,
                                 uv0: (Float, Float),
                                 spanU: ClosedRange<Float>? = nil,
                                 spanV: ClosedRange<Float>? = nil,
                                 e1: Float = 1e-6,
                                 e2: Float = 1e-6,
                                 maxIteration: Int = 100) -> (Float, Float) {
        var iteration = 0
        var uvi = uv0
        
        let intervalU = spanU ?? (curveA.basis.knots.first!.value ... curveA.basis.knots.last!.value)
        let intervalV = spanV ?? (curveB.basis.knots.first!.value ... curveB.basis.knots.last!.value)
        
        while true {
            let ui = uvi.0
            let vi = uvi.1
            let pAi = curveA.point(at: ui)!
            let pBi = curveB.point(at: vi)!
            
            let offsetAB = pBi - pAi
            let offsetBA = pAi - pBi
            
            let potentialTangentA = curveA.points(at: ui, derivativeOrder: 1)
            let tangentAIndex = if abs(dot(normalize(potentialTangentA.first!), offsetAB)) > abs(dot(normalize(potentialTangentA.last!), offsetAB)) {
                1
            } else { 0 }
            let tangentA = potentialTangentA[tangentAIndex]
            
            let potentialTangentB = curveB.points(at: vi, derivativeOrder: 1)
            let tangentBIndex = if abs(dot(normalize(potentialTangentB.first!), offsetBA)) > abs(dot(normalize(potentialTangentB.last!), offsetBA)) {
                1
            } else { 0 }
            let tangentB = potentialTangentB[tangentBIndex]
            
            let acceleratorA = curveA.points(at: ui, derivativeOrder: 2)[tangentAIndex]
            let acceleratorB = curveB.points(at: vi, derivativeOrder: 2)[tangentBIndex]
            
            let offsetLength = length(offsetAB)
            let cosineA = abs(dot(tangentA, offsetAB)) / (length(tangentA) * offsetLength)
            let cosineB = abs(dot(tangentB, offsetBA)) / (length(tangentB) * offsetLength)
            
            let pointCoincident = offsetLength < e1
            let cosineIsZero = cosineA < e2 && cosineB < e2
            if pointCoincident && cosineIsZero {
                return uvi
            }
            
            let uj = ui
            let vj = vi
            
            let a = dot(acceleratorA, offsetAB) - length_squared(tangentA)
            let b = dot(tangentA, tangentB)
            let c = dot(acceleratorB, offsetBA) - length_squared(tangentB)
            let n = dot(tangentA, offsetBA)
            let m = dot(tangentB, offsetAB)
            
            let denom = b * b - a * c
            let deltaU = (b * m - c * n) / denom
            let deltaV = (b * n - a * m) / denom
            
            uvi = (ui + deltaU, vi + deltaV)
            iteration = iteration + 1
            
            if uvi.0 < intervalU.lowerBound {
                uvi.0 = intervalU.lowerBound
            } else if uvi.0 > intervalU.upperBound {
                uvi.0 = intervalU.upperBound
            }
            
            if uvi.1 < intervalV.lowerBound {
                uvi.1 = intervalV.lowerBound
            } else if uvi.1 > intervalV.upperBound {
                uvi.1 = intervalV.upperBound
            }
            
            if length((uvi.0 - uj) * tangentA + (uvi.1 - vj) * tangentB) < e1 {
                return uvi
            }
            
            if pointCoincident || cosineIsZero {
                return (uj, vj)
            }
            
            if iteration >= maxIteration {
                print("max iteration")
                return uvi
            }
        }
    }
    
    static func nearestParameter(_ curveA: BSplineCurve,
                                 _ curveB: BSplineCurve,
                                 startValueCandidatesA: [(Float, SIMD3<Float>)] = [],
                                 startValueCandidatesB: [(Float, SIMD3<Float>)] = [],
                                 e1: Float = 1e-6,
                                 e2: Float = 1e-6,
                                 maxIteration: Int = 100) -> (Float, Float) {
        let uv0 = startValueForProjection(curveA, curveB, 
                                          candidatesA: startValueCandidatesA,
                                          candidatesB: startValueCandidatesB)
        
        let uSpan = curveA.basis.containingKnotSpans(of: uv0.0)
        let vSpan = curveB.basis.containingKnotSpans(of: uv0.1)
        
        return nearestParameter(curveA, curveB, uv0: uv0,
                                spanU: uSpan.first!.start.knot.value ... uSpan.last!.end.knot.value,
                                spanV: vSpan.first!.start.knot.value ... vSpan.last!.end.knot.value,
                                e1: e1, e2: e2, maxIteration: maxIteration)
    }
}
