//
//  ObjectParser.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/19.
//

import Foundation

class JSONObjectParser {
    static func dump(samples: [SpanSample]) -> Data? {
        let sortedFunctionSamples = samples.flatMap { $0.samples }.sorted { $0.basisID < $1.basisID }
        
        var currentBasisId = -1
        var groupedFunctionSamples: [FunctionSample] = []
        for fs in sortedFunctionSamples {
            if currentBasisId != fs.basisID {
                currentBasisId = fs.basisID
                groupedFunctionSamples.append(fs)
            } else {
                if abs(fs.samples.first!.1 - groupedFunctionSamples.last!.samples.last!.1) > 1e-3 {
                    groupedFunctionSamples.append(fs)
                } else {
                    groupedFunctionSamples[groupedFunctionSamples.count - 1]
                        .samples.append(contentsOf: fs.samples)
                }
            }
        }
        
        let json: [Any] = groupedFunctionSamples.map { sample in
            [
                "basisID": sample.basisID,
                "samples": sample.samples.map { [$0.0, $0.1] }
            ]
        }
        
        return try? JSONSerialization.data(withJSONObject: json)
    }
    
    static func dump(drawable: DrawableBase) -> Data? {
        switch drawable {
        case is BSplineCurve: dump(curve: drawable as! BSplineCurve)
        case is BSplineSurface: dump(surface: drawable as! BSplineSurface)
        default: nil
        }
    }
    
    static func dump(surface: BSplineSurface) -> Data? {
        var uKnots: [[String:Any]] = []
        for knot in surface.uBasis.knots {
            uKnots.append([
                "value": knot.value, "multiplicity": knot.multiplicity
            ])
        }
        
        var vKnots: [[String:Any]] = []
        for knot in surface.vBasis.knots {
            vKnots.append([
                "value": knot.value, "multiplicity": knot.multiplicity
            ])
        }
        
        var controlPoints: [[[Float]]] = []
        
        for row in surface.controlNet {
            var cpRow: [[Float]] = []
            for point in row {
                cpRow.append([point.x, point.y, point.z, point.w])
            }
            controlPoints.append(cpRow)
        }
        
        
        let data: [String : Any] = [
            "uDegree": surface.uBasis.degree,
            "vDegree": surface.vBasis.degree,
            "uKnots": uKnots,
            "vKnots": vKnots,
            "controlPoints": controlPoints
        ]
        
        let jsonObject: [String: Any] = [
            "type": "surface",
            "data": data
        ]
        
        return try? JSONSerialization.data(withJSONObject: jsonObject)
    }
    
    static func dump(curve: BSplineCurve) -> Data? {
        var knots: [[String:Any]] = []
        for knot in curve.basis.knots {
            knots.append([
                "value": knot.value, "multiplicity": knot.multiplicity
            ])
        }
        
        var controlPoints: [[Float]] = []
        for point in curve.controlPoints {
            controlPoints.append([point.x, point.y, point.z, point.w])
        }
        
        let data: [String : Any] = [
            "degree": curve.basis.degree,
            "knots": knots,
            "controlPoints": controlPoints
        ]
        
        let jsonObject: [String: Any] = [
            "type": "curve",
            "data": data
        ]
        
        return try? JSONSerialization.data(withJSONObject: jsonObject)
    }
    
    static func parse(_ url: URL) -> DrawableBase? {
        guard let data = try? Data(contentsOf: url) else {
            print("cannot read data from \(url)")
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            print("cannot parse file to JSON")
            return nil
        }
        guard let dictionary = json as? [String: Any] else {
            print("json root is not a dictionary")
            return nil
        }
        guard let type = dictionary["type"] as? String else {
            print("cannot resolve .type")
            return nil
        }
        guard let data = dictionary["data"] else {
            print("cannot resolve .data")
            return nil
        }
        return switch type {
        case "curve":
            if let data = data as? [String: Any] {
                parseCurve(jsonObject: data)
            } else { nil }
        case "surface":
            if let data = data as? [String: Any] {
                parseSurface(jsonObject: data)
            } else { nil }
        default: nil
        }
    }
    
    static func parseSurface(jsonObject: [String: Any]) -> BSplineSurface? {
        guard let uDegree = jsonObject["uDegree"] as? Int else {
            print("cannot resolve *.uDegree")
            return nil
        }
        
        guard let vDegree = jsonObject["vDegree"] as? Int else {
            print("cannot resolve *.vDegree")
            return nil
        }
        
        guard let uKnots = jsonObject["uKnots"] as? [Any] else {
            print("cannot resolve *.uKnots")
            return nil
        }
        
        guard let vKnots = jsonObject["vKnots"] as? [Any] else {
            print("cannot resolve *.vKnots")
            return nil
        }
        
        guard let controlPoints = jsonObject["controlPoints"] as? [Any] else {
            print("cannot resolve *.controlPoints")
            return nil
        }
        
        var surfaceUKnots: [BSplineBasis.Knot] = []
        var uKnotsMultiplicitySum = 0
        for (index, uKnot) in uKnots.enumerated() {
            guard let uKnot = uKnot as? [String: Any] else {
                print("cannot resolve *.uKnots[\(index)]")
                return nil
            }
            guard let multiplicity = uKnot["multiplicity"] as? Int else {
                print("cannot resolve *.knots[\(index)].multiplicity")
                return nil
            }
            guard let value = uKnot["value"] as? Double else {
                print("cannot resolve *.knots[\(index)].value, the value is \(uKnot["value"] ?? "nil")")
                return nil
            }
            surfaceUKnots.append(.init(value: Float(value), multiplicity: multiplicity))
            uKnotsMultiplicitySum = uKnotsMultiplicitySum + multiplicity
        }
        
        var surfaceVKnots: [BSplineBasis.Knot] = []
        var vKnotsMultiplicitySum = 0
        for (index, vKnot) in vKnots.enumerated() {
            guard let vKnot = vKnot as? [String: Any] else {
                print("cannot resolve *.vKnots[\(index)]")
                return nil
            }
            guard let multiplicity = vKnot["multiplicity"] as? Int else {
                print("cannot resolve *.knots[\(index)].multiplicity")
                return nil
            }
            guard let value = vKnot["value"] as? Double else {
                print("cannot resolve *.knots[\(index)].value, the value is \(vKnot["value"] ?? "nil")")
                return nil
            }
            surfaceVKnots.append(.init(value: Float(value), multiplicity: multiplicity))
            vKnotsMultiplicitySum = vKnotsMultiplicitySum + multiplicity
        }
        
        guard vKnotsMultiplicitySum - vDegree - 1 == controlPoints.count else {
            print("control points do not match vKnots and vDegree")
            return nil
        }
        
        var controlNet: [[SIMD4<Float>]] = []
        for (j, row) in controlPoints.enumerated() {
            guard let row = row as? [Any] else {
                print("cannot resolve *.controlPoints[\(j)]")
                return nil
            }
            
            guard uKnotsMultiplicitySum - uDegree - 1 == row.count else {
                print("control points do not match uKnots and uDegree at row \(j)")
                return nil
            }
            
            var controlNetRow: [SIMD4<Float>] = []
            for (i, point) in row.enumerated() {
                guard let point = point as? [Double] else {
                    print("cannot resolve *.controlPoints[\(j)][\(i)]")
                    return nil
                }
                guard point.count == 4 else {
                    print("*.controlPoints[\(j)][\(i)] is not a vector of 4 scalars")
                    return nil
                }
                
                controlNetRow.append(.init(x: Float(point[0]),
                                                y: Float(point[1]),
                                                z: Float(point[2]),
                                                w: Float(point[3])))
            }
            controlNet.append(controlNetRow)
        }
        
        return .init(uKnots: surfaceUKnots, vKnots: surfaceVKnots, degrees: (uDegree, vDegree), controlNet: controlNet)
    }
    
    static func parseCurve(jsonObject: [String: Any]) -> BSplineCurve? {
        guard let degree = jsonObject["degree"] as? Int else {
            print("cannot resolve *.degree")
            return nil
        }
        
        guard let knots = jsonObject["knots"] as? [Any] else {
            print("cannot resolve *.knots")
            return nil
        }
        guard let controlPoints = jsonObject["controlPoints"] as? [Any] else {
            print("cannot resolve *.controlPoints")
            return nil
        }
        
        var curveKnots: [BSplineBasis.Knot] = []
        var multiplicitySum = 0
        for (index, knot) in knots.enumerated() {
            guard let knot = knot as? [String: Any] else {
                print("cannot resolve *.knots[\(index)]")
                return nil
            }
            guard let multiplicity = knot["multiplicity"] as? Int else {
                print("cannot resolve *.knots[\(index)].multiplicity")
                return nil
            }
            guard let value = knot["value"] as? Double else {
                print("cannot resolve *.knots[\(index)].value, the value is \(knot["value"] ?? "nil")")
                return nil
            }
            curveKnots.append(.init(value: Float(value), multiplicity: multiplicity))
            multiplicitySum = multiplicitySum + multiplicity
        }
        
        guard multiplicitySum - degree - 1 == controlPoints.count else {
            print("control points do not match knots and degree")
            return nil
        }
        
        var curveControlPoints: [SIMD4<Float>] = []
        for (index, point) in controlPoints.enumerated() {
            guard let point = point as? [Double] else {
                print("cannot resolve *.controlPoints[\(index)]")
                return nil
            }
            guard point.count == 4 else {
                print("*.controlPoints[\(index)] is not a vector of 4 scalars")
                return nil
            }
            curveControlPoints.append(.init(x: Float(point[0]),
                                            y: Float(point[1]),
                                            z: Float(point[2]),
                                            w: Float(point[3])))
        }
        
        return .init(knots: curveKnots, controlPoints: curveControlPoints, degree: degree)
    }
}
