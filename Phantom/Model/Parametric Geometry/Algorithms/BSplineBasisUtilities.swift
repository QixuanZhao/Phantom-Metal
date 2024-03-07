//
//  BSplineBasisFunction.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/3/1.
//

import Foundation

extension BSplineBasis {
    
    func containingKnotSpans(of parameter: Float) -> [KnotSpan] {
        self.knotSpans.filter { span in
            span.start.knot.value <= parameter && parameter <= span.end.knot.value
        }
    }
    
    struct BasisEvaluationResult {
        let values: [Float]
        
        let parameter: Float
        let knotSpan: KnotSpan
        let degree: Int
        let derivativeOrder: Int
        
        let firstBasisIndex: Int
        let lastBasisIndex: Int
    }
    
    // return (start function index, [function value])
    // order: derivative order
    func value(at u: Float, 
               degree p: Int? = nil,
               derivativeOrder: Int = 0) -> [BasisEvaluationResult] {
        
        let degree = min(p ?? self.degree, self.degree)
        
        guard degree >= 0 else { return [] }
        guard derivativeOrder >= 0 else { return [] }
        
        let order = degree + 1
        let U = self.knotVector
        
        var knotSpans = containingKnotSpans(of: u)
        if derivativeOrder == 0 && knotSpans.count > 1 {
            knotSpans.removeLast(knotSpans.count - 1)
        }
        
        return knotSpans.map { span in
            let lastBasisIndex = span.start.lastIndex
            
            var value: Array<Float> = .init(repeating: 0, count: order)
            guard derivativeOrder <= degree else {
                return BasisEvaluationResult(values: value,
                                             parameter: u,
                                             knotSpan: span,
                                             degree: degree,
                                             derivativeOrder: derivativeOrder,
                                             firstBasisIndex: lastBasisIndex - degree,
                                             lastBasisIndex: lastBasisIndex)
            }
            
            value[0] = 1
            for p in 1 ..< order - derivativeOrder {
                // calculate N_{i,p} for i in lastBasisIndex - p ... lastBasisIndex
                // N_{i,p}(u) = \frac{u - u_i}{u_{i+p} - u_i} N_{i,p-1}(u) + \frac{u_{i+p+1} - u}{u_{i+p+1} - u_{i+1}} N_{i+1,p-1}(u)
                var left: Float = value[p - 1] / (U[lastBasisIndex + p] - U[lastBasisIndex])
                value[p] = left * (u - U[lastBasisIndex])
                
                var right: Float = left
                
                for k in 1..<p {
                    let i = lastBasisIndex - k
                    
                    left = value[p - 1 - k] / (U[i + p] - U[i])
                    value[p - k] = left * (u - U[i]) + right * (U[i + p + 1] - u)
                    right = left
                }
                
                value[0] = right * (U[lastBasisIndex + 1] - u)
            }
            
            for p in order - derivativeOrder ..< order {
                
                var left: Float = value[p - 1] / (U[lastBasisIndex + p] - U[lastBasisIndex])
                value[p] = left * Float(p)
                
                var right: Float = left
                
                for k in 1..<p {
                    let i = lastBasisIndex - k
                    
                    left = value[p - 1 - k] / (U[i + p] - U[i])
                    value[p - k] = Float(p) * (left - right)
                    right = left
                }
                
                value[0] = -right * Float(p)
            }
            
            return BasisEvaluationResult(values: value,
                                         parameter: u,
                                         knotSpan: span,
                                         degree: degree,
                                         derivativeOrder: derivativeOrder,
                                         firstBasisIndex: lastBasisIndex - degree,
                                         lastBasisIndex: lastBasisIndex)
        }
    }
}
