//
//  BSplineCurveUtilities.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/3/2.
//

import simd

extension BSplineCurve {
    func point(at u: Float, derivativeOrder: Int = 0) -> SIMD3<Float>? {
        let points = points(at: u, derivativeOrder: derivativeOrder)
        
        if points.count == 1 { return points.first! }
        if points.count == 2 {
            let leftPoint = points[0]
            let rightPoint = points[1]
            
            if distance(leftPoint, rightPoint) > 1e-6 { return nil }
            else { return (leftPoint + rightPoint) / 2 }
        }
        
        return nil
    }
    
    func points(at u: Float, derivativeOrder: Int = 0) -> [SIMD3<Float>] {
        let functions = basis.value(at: u, derivativeOrder: derivativeOrder)
        
        return functions.map { N in
            let values = N.values
            var result: SIMD4<Float> = .zero
            for i in 0..<basis.order {
                result = result + values[i] * controlPoints[i + N.firstBasisIndex]
            }
            
            return [result.x, result.y, result.z]
        }
    }
    
    
    /**
     * return a sorted sequence of curves, each element of which is a separate curve split at given parameter
     */
    func split(at u: any Collection<Float>) -> [BSplineCurve] {
        let U = u.sorted(by: <)
        
        guard !U.isEmpty else { return [] }
        
        var result: [BSplineCurve] = []
        var root = self
        for u in U {
            guard let splitCurves = root.split(at: u) else { return [] }
            result.append(splitCurves.0)
            root = splitCurves.1
        }
        result.append(root)
        
        return result
    }
    
    func split(at u: Float) -> (BSplineCurve, BSplineCurve)? {
        let start = basis.knots.first!.value
        let end = basis.knots.last!.value
        
        if u <= start || u >= end { return nil }
        
        let that = self.clone()
        
        var knots1: [BSplineBasis.Knot] = []
        var knots2: [BSplineBasis.Knot] = [.init(value: u, multiplicity: basis.order)]
        
        var splitPointIndex: Int = -1
        
        for knot in basis.knots {
            if knot.value < u {
                splitPointIndex = splitPointIndex + knot.multiplicity
                knots1.append(knot)
            }
            else if knot.value > u { knots2.append(knot) }
        }
        knots1.append(.init(value: u, multiplicity: basis.order))
        
        for _ in 0..<basis.degree { that.insert(knotValue: u) }
        
        var controlPoints1: [SIMD4<Float>] = []
        var controlPoints2: [SIMD4<Float>] = []
        
        for i in 0..<that.controlPoints.count {
            if i < splitPointIndex {
                controlPoints1.append(that.controlPoints[i])
            } else if i > splitPointIndex {
                controlPoints2.append(that.controlPoints[i])
            } else {
                controlPoints1.append(that.controlPoints[i])
                controlPoints2.append(that.controlPoints[i])
            }
        }
        
        let c1 = BSplineCurve(knots: knots1, controlPoints: controlPoints1, degree: basis.degree)
        let c2 = BSplineCurve(knots: knots2, controlPoints: controlPoints2, degree: basis.degree)
        
        return (c1, c2)
    }
    
    func reparameterized(into domain: ClosedRange<Float>) -> BSplineCurve? {
        guard domain.upperBound > domain.lowerBound else { return nil }
        
        let domainLength = domain.upperBound - domain.lowerBound
        
        let originalKnots = basis.knots
        let originalDomainMin = originalKnots.first!.value
        let originalDomainMax = originalKnots.last!.value
        let originalDomainLength = originalDomainMax - originalDomainMin
        
        let knots = originalKnots.map { knot in
            BSplineBasis.Knot(value: (knot.value - originalDomainMin) * domainLength / originalDomainLength + domain.lowerBound,
                              multiplicity: knot.multiplicity)
        }
        
        return BSplineCurve(knots: knots,
                            controlPoints: controlPoints,
                            degree: basis.degree,
                            showControlPoints: false)
    }
    
    func reversed() -> BSplineCurve {
        let domainMin = self.basis.knots.first!.value
        let domainMax = self.basis.knots.last!.value
//        let domainLength = domainMax - domainMin
        let knots = self.basis.knots.reversed().map { BSplineBasis.Knot(value: (domainMin + domainMax - $0.value), multiplicity: $0.multiplicity) }
        let controlPoints = self.controlPoints.reversed().map { $0 }
        
        return BSplineCurve(knots: knots, controlPoints: controlPoints, degree: basis.degree, showControlPoints: showControlPoints)
    }
}

extension BSplineCurve {
    
    static func combine(curves: [BSplineCurve],
                        domainStart: Float,
                        domainJoints: [Float],
                        domainEnd: Float) -> BSplineCurve? {
        guard !curves.isEmpty && curves.count - 1 == domainJoints.count else { return nil }
        
        let degree = curves.first!.basis.degree
        guard curves.allSatisfy({ $0.basis.degree == degree }) else { return nil }
        
        let joints = (0..<domainJoints.count).map { i in
            (curves[i].controlPoints.last! + curves[i + 1].controlPoints.first!) / 2
        }
        
        var domainNodes = [domainStart]
        domainNodes.append(contentsOf: domainJoints)
        domainNodes.append(domainEnd)
        
        let alignedCurves = try? curves.enumerated().map { (i, curve) in
            let currentCurveDomainStart = domainNodes[i]
            let currentCurveDomainEnd = domainNodes[i + 1]
            guard currentCurveDomainStart < currentCurveDomainEnd else {
                throw PhantomError.unknownError("unsorted joints")
            }
            return curve.reparameterized(into: domainNodes[i] ... domainNodes[i + 1])!
        }
        
        guard let alignedCurves else { return nil }
        
        let innerControlPoints = alignedCurves.map {
            var result = $0.controlPoints
            result.removeFirst()
            result.removeLast()
            return result
        }
        
        let innerKnots = alignedCurves.map {
            var result = $0.basis.knots
            result.removeFirst()
            result.removeLast()
            return result
        }
        
        var controlPointCollection = [ [alignedCurves.first!.controlPoints.first!] ]
        for (i, p) in joints.enumerated() {
            controlPointCollection.append(innerControlPoints[i])
            controlPointCollection.append([p])
        }
        controlPointCollection.append(innerControlPoints.last!)
        controlPointCollection.append([alignedCurves.last!.controlPoints.last!])
        
        let controlPoints = controlPointCollection.flatMap { $0 }
        
        var knotCollection = [[BSplineBasis.Knot(value: domainStart, multiplicity: degree + 1)]]
        for (i, k) in domainJoints.enumerated() {
            knotCollection.append(innerKnots[i])
            knotCollection.append([BSplineBasis.Knot(value: k, multiplicity: degree)])
        }
        knotCollection.append(innerKnots.last!)
        knotCollection.append([.init(value: domainEnd, multiplicity: degree + 1)])
        
        let knots = knotCollection.flatMap { $0 }
        
        return BSplineCurve(knots: knots, controlPoints: controlPoints, degree: degree, showControlPoints: false)
    }
    
    static func combine(curveA: BSplineCurve, curveB: BSplineCurve,
                        domainStart: Float,
                        domainJoint: Float,
                        domainEnd: Float) -> BSplineCurve? {
        guard domainStart < domainJoint && domainJoint < domainEnd else { return nil }
        guard curveA.basis.degree == curveB.basis.degree else { return nil }
        
        let degree = curveA.basis.degree
        
        let a = curveA.reparameterized(into: domainStart...domainJoint)!
        let b = curveB.reparameterized(into: domainJoint...domainEnd)!
        
        let joint = (a.controlPoints.last! + b.controlPoints.first!) / 2
        
        var leftControlPoints = a.controlPoints
        var rightControlPoints = b.controlPoints
        leftControlPoints.removeLast()
        rightControlPoints.removeFirst()
        
        let controlPoints = [leftControlPoints, [joint], rightControlPoints].flatMap { $0 }
        
        var leftKnots = a.basis.knots
        var rightKnots = b.basis.knots
        leftKnots.removeLast()
        rightKnots.removeFirst()
        
        let knots = [leftKnots, [BSplineBasis.Knot(value: domainJoint, multiplicity: degree)], rightKnots].flatMap { $0 }
        
        return BSplineCurve(knots: knots, controlPoints: controlPoints, degree: degree, showControlPoints: false)
    }
}
