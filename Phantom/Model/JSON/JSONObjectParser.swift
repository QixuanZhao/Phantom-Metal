//
//  ObjectParser.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/19.
//

import Foundation

class JSONObjectParser {
    static func parse(_ url: URL) -> DrawableBase? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let dictionary = json as? [String: Any] else { return nil }
        guard let type = dictionary["type"] as? String else { return nil }
        guard let data = dictionary["data"] else { return nil }
        return switch type {
        case "curve":
            if let data = data as? [String: Any] {
                parseCurve(jsonObject: data)
            } else { nil }
        default: nil
        }
    }
    
    static func parseCurve(jsonObject: [String: Any]) -> BSplineCurve? {
        guard let degree = jsonObject["degree"] as? Int else { return nil }
        guard let knots = jsonObject["knots"] as? [Any] else { return nil }
        guard let controlPoints = jsonObject["controlPoints"] as? [Any] else { return nil }
        
        var curveKnots: [BSplineBasis.Knot] = []
        for knot in knots {
            guard let knot = knot as? [String: Any] else { return nil }
            guard let multiplicity = knot["multiplicity"] as? Int else { return nil }
            guard let value = knot["value"] as? Float else { return nil }
            curveKnots.append(.init(value: value, multiplicity: multiplicity))
        }
        
        var curveControlPoints: [SIMD4<Float>] = []
        for point in controlPoints {
            guard let point = point as? [Float] else { return nil }
            guard point.count == 4 else { return nil }
            curveControlPoints.append(.init(x: point[0], y: point[1], z: point[2], w: point[3]))
        }
        
        return .init(knots: curveKnots, controlPoints: curveControlPoints, degree: degree)
    }
}
