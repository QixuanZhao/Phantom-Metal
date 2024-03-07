//
//  BSplineSurfaceUtilities.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/3/2.
//

import simd

extension BSplineSurface {
    func isocurve(u: Float, derivativeOrder: Int = 0) -> BSplineCurve? {
        let curves = isocurves(u: u, derivativeOrder: derivativeOrder)
        
        if curves.count == 1 { return curves.first! }
        else if curves.count == 2 {
            if derivativeOrder == 0 { return curves.first! }
            else {
                let curveLeft = curves.first!
                let curveRight = curves.last!
                
                var d: Float = 0
                for i in 0..<curveLeft.controlPoints.count {
                    let pointLeft = curveLeft.controlPoints[i]
                    let pointRight = curveRight.controlPoints[i]
                    d = d + distance(pointLeft, pointRight)
                }
                
                if d > 1e-6 { return nil }
                else { return curveLeft }
            }
        }
        return nil
    }
    
    func isocurve(v: Float, derivativeOrder: Int = 0) -> BSplineCurve? {
        let curves = isocurves(v: v, derivativeOrder: derivativeOrder)
        
        if curves.count == 1 { return curves.first! }
        else if curves.count == 2 {
            if derivativeOrder == 0 { return curves.first! }
            else {
                let curveLeft = curves.first!
                let curveRight = curves.last!
                
                var d: Float = 0
                for i in 0..<curveLeft.controlPoints.count {
                    let pointLeft = curveLeft.controlPoints[i]
                    let pointRight = curveRight.controlPoints[i]
                    d = d + distance(pointLeft, pointRight)
                }
                
                if d > 1e-6 { return nil }
                else { return curveLeft }
            }
        }
        return nil
    }
    
    func isocurves(u: Float, derivativeOrder: Int = 0) -> [BSplineCurve] {
        let functions = uBasis.value(at: u, derivativeOrder: derivativeOrder)
        
        return functions.map { function in
            var isocurveControlPoints: [SIMD4<Float>] = []
            for j in 0..<vBasis.multiplicitySum - vBasis.order {
                var point = SIMD4<Float>.zero
                for i in 0..<uBasis.order {
                    point = point + function.values[i] * controlNet[j][i + function.firstBasisIndex]
                }
                isocurveControlPoints.append(point)
            }
            
            return BSplineCurve(knots: vBasis.knots, controlPoints: isocurveControlPoints, degree: vBasis.degree)
        }
    }
    
    func isocurves(v: Float, derivativeOrder: Int = 0) -> [BSplineCurve] {
        let functions = vBasis.value(at: v, derivativeOrder: derivativeOrder)
        
        return functions.map { function in
            var isocurveControlPoints: [SIMD4<Float>] = []
            for i in 0..<uBasis.multiplicitySum - uBasis.order {
                var point = SIMD4<Float>.zero
                for j in 0..<vBasis.order {
                    point = point + function.values[j] * controlNet[j + function.firstBasisIndex][i]
                }
                isocurveControlPoints.append(point)
            }
            
            return BSplineCurve(knots: uBasis.knots, controlPoints: isocurveControlPoints, degree: uBasis.degree)
        }
    }
    
    func points(at uv: SIMD2<Float>, derivativeOrder: (Int, Int) = (0, 0)) -> [[SIMD3<Float>]] {
        let uFunctions = uBasis.value(at: uv[0], derivativeOrder: derivativeOrder.0)
        let vFunctions = vBasis.value(at: uv[1], derivativeOrder: derivativeOrder.1)
        
        var results: [[SIMD3<Float>]] = []
        
        for N in uFunctions {
            var temp: [SIMD3<Float>] = []
            for M in vFunctions {
                var result: SIMD4<Float> = .zero
                for i in 0..<uBasis.order {
                    for j in 0..<vBasis.order {
                        result = result + N.values[i] * M.values[j] * controlNet[j + M.firstBasisIndex][i + N.firstBasisIndex]
                    }
                }
                temp.append([result.x, result.y, result.z])
            }
            results.append(temp)
        }
        
        return results
    }
    
    func point(at uv: SIMD2<Float>, derivativeOrder: (Int, Int) = (0, 0)) -> SIMD3<Float>? {
        let points = points(at: uv, derivativeOrder: derivativeOrder)
        
        if points.count == 1 {
            let nPoints = points.first!
            if nPoints.count == 1 {
                return nPoints.first!
            } else if nPoints.count == 2 {
                let m1 = nPoints.first!
                let m2 = nPoints.last!
                if distance(m1, m2) > 1e-6 { return nil }
                else { return (m1 + m2) / 2 }
            }
        }
        if points.count == 2 {
            let n1 = points.first!
            let n2 = points.last!
            
            if n1.count == 1 && n2.count == 1 {
                let p1 = n1.first!
                let p2 = n2.first!
                if distance(p1, p2) > 1e-6 { return nil }
                else { return (p1 + p2) / 2 }
            } else if n1.count == 2 && n2.count == 2 {
                let p00 = n1.first!
                let p01 = n1.last!
                let p10 = n2.first!
                let p11 = n2.last!
                
                if distance(p00, p01) > 1e-6 ||
                    distance(p00, p10) > 1e-6 ||
                    distance(p11, p01) > 1e-6 ||
                    distance(p11, p10) > 1e-6 {
                    return nil
                } else {
                    return (p00 + p01 + p10 + p11) / 4
                }
            }
        }
        return nil
    }
    
}

