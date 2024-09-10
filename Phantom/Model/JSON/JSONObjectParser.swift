//
//  ObjectParser.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/19.
//

import Foundation

class JSONObjectParser {
    static func dump(camera: Camera) -> Data? {
        let data: [String: Any] = [
            "position": [ camera.position.x, camera.position.y, camera.position.z ],
            "pitch": camera.pitch,
            "yaw": camera.yaw,
            "roll": camera.roll
        ]
        
        let json: [String: Any] = [
            "type": "camera",
            "data": data
        ]
        
        return try? JSONSerialization.data(withJSONObject: json)
    }
    
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
    
    // drawable dump function
    // dispatcher function
    static func dump(drawable: DrawableBase) -> Data? {
        switch drawable {
        case is BSplineCurve: dump(curve: drawable as! BSplineCurve)
        case is BSplineSurface: dump(surface: drawable as! BSplineSurface)
        case is LineSegments: dump(lineSegments: drawable as! LineSegments)
        case is PointSet: dump(pointSet: drawable as! PointSet)
        default: nil
        }
    }
    
    static func dump(pointSet: PointSet) -> Data? {
        let points = pointSet.points
        
        let data: [String: Any] = [
            "points": points.map { [$0.x, $0.y, $0.z] },
            "color": [pointSet.color.x, pointSet.color.y, pointSet.color.z, pointSet.color.w]
        ]
        
        let jsonObject: [String: Any] = [
            "type": "point set",
            "data": data
        ]
        
        return try? JSONSerialization.data(withJSONObject: jsonObject)
    }
    
    static func dump(lineSegments: LineSegments) -> Data? {
        let segments = lineSegments.segments.map {
            [ [$0.0.x, $0.0.y, $0.0.z], [$0.1.x, $0.1.y, $0.1.z] ]
        }
        
        let strategy = switch lineSegments.colorBy {
        case .mono: "mono"
        case .lengthBinary: "length binary"
        case .lengthLinear: "length linear"
        case .lengthLinearTruncated: "length linear truncated"
        }
        
        var color: [String: Any] = [
            "strategy": strategy,
            "color1": [ lineSegments.color1.x, lineSegments.color1.y, lineSegments.color1.z, lineSegments.color1.w ],
            "color2": [ lineSegments.color2.x, lineSegments.color2.y, lineSegments.color2.z, lineSegments.color2.w ]
        ]
        
        switch lineSegments.colorBy {
        case .lengthBinary(let standard):
            color["standard"] = standard
        case .lengthLinearTruncated(let standard):
            color["standard"] = standard
        default: break
        }
        
        let data: [String: Any] = [
            "segments": segments,
            "color": color
        ]
        
        let jsonObject: [String: Any] = [
            "type": "line segments",
            "data": data
        ]
        
        return try? JSONSerialization.data(withJSONObject: jsonObject)
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
    
    static func parse(cameraURL url: URL) -> Camera? {
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
        case "camera":
            if let data = data as? [String: Any] {
                parse(cameraJson: data)
            } else { nil }
        default: nil
        }
    }
    
    static func parse(cameraJson: [String: Any]) -> Camera? {
        guard let position = cameraJson["position"] as? [Double] else {
            print("position not found")
            return nil
        }
        
        guard position.count == 3 else {
            print("position is not a 3D vector")
            return nil
        }
        
        guard let pitch = cameraJson["pitch"] as? Double else {
            print("pitch not found")
            return nil
        }
        
        guard let yaw = cameraJson["yaw"] as? Double else {
            print("yaw not found")
            return nil
        }
        
        let roll = (cameraJson["roll"] as? Double) ?? 0
        
        let camera = Camera()
        camera.position = .init(Float(position[0]), Float(position[1]), Float(position[2]))
        camera.yaw = Float(yaw)
        camera.pitch = Float(pitch)
        camera.roll = Float(roll)
        
        return camera
    }
    
    // drawable parse function
    // dispatcher function
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
        return if let data = data as? [String: Any] {
            switch type {
            case "curve":
                parse(curveJson: data)
            case "surface":
                parse(surfaceJson: data)
            case "line segments":
                parse(lineSegmentsJson: data)
            case "point set":
                parse(pointSet: data)
            default: nil
            }
        } else { nil }
    }
    
    static func parse(pointSet: [String: Any]) -> PointSet? {
        guard !pointSet.isEmpty else {
            print("dictionary is empty")
            return nil
        }
        
//        guard let color = pointSet["color"] as? [Double] else {
//            print("no color found")
//            return nil
//        }
        
        guard let points = pointSet["points"] as? [Any] else {
            print("no points")
            return nil
        }
        
        guard !points.isEmpty else { return nil }
        
        let psPoints = points.map { point in
            let p = point as! [Double]
            let x = Float(p[0])
            let y = Float(p[1])
            let z = Float(p[2])
            return SIMD3<Float>(x, y, z)
        }
        
        let result = PointSet(points: psPoints)
        return result
    }
    
    static func parse(lineSegmentsJson: [String: Any]) -> LineSegments? {
        guard !lineSegmentsJson.isEmpty else {
            print("dictionary is empty")
            return nil
        }
        
        do {
            guard let array = lineSegmentsJson["segments"] as? [Any] else {
                print("segments not found")
                return nil
            }
            
            let segments = try array.map { segment in
                guard let s = segment as? [[Double]] else {
                    throw PhantomError.unknownError("segment is not [[Double]]")
                }
                
                guard s.count == 2 else {
                    throw PhantomError.unknownError("segment element count is not 2")
                }
                
                return (SIMD3<Float>(Float(s[0][0]), Float(s[0][1]), Float(s[0][2])),
                        SIMD3<Float>(Float(s[1][0]), Float(s[1][1]), Float(s[1][2])))
            }
            
            let lineSegments = LineSegments(segments: segments)
            
            if let color = lineSegmentsJson["color"] as? [String: Any] {
                if let strategy = color["strategy"] as? String,
                   let color1 = color["color1"] as? [Double],
                   let color2 = color["color2"] as? [Double] {
                    var s = LineSegments.ColorStrategy.mono
                    switch strategy {
                    case "length binary": 
                        let standard = (color["standard"] as? Double) ?? 0.1
                        s = LineSegments.ColorStrategy.lengthBinary(standard: Float(standard))
                    case "length linear":
                        s = LineSegments.ColorStrategy.lengthLinear
                    case "length linear truncated":
                        let standard = (color["standard"] as? Double) ?? 0.1
                        s = LineSegments.ColorStrategy.lengthLinearTruncated(standard: Float(standard))
                    default: break
                    }
                    
                    lineSegments.setColorStrategy(s)
                    
                    if color1.count == 4 && color2.count == 4 {
                        lineSegments.setColor(.init(Float(color1[0]), Float(color1[1]), Float(color1[2]), Float(color1[3])),
                                              .init(Float(color2[0]), Float(color2[1]), Float(color2[2]), Float(color2[3])))
                    }
                }
            }
            
            return lineSegments
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    static func parse(surfaceJson: [String: Any]) -> BSplineSurface? {
        guard let uDegree = surfaceJson["uDegree"] as? Int else {
            print("cannot resolve *.uDegree")
            return nil
        }
        
        guard let vDegree = surfaceJson["vDegree"] as? Int else {
            print("cannot resolve *.vDegree")
            return nil
        }
        
        guard let uKnots = surfaceJson["uKnots"] as? [Any] else {
            print("cannot resolve *.uKnots")
            return nil
        }
        
        guard let vKnots = surfaceJson["vKnots"] as? [Any] else {
            print("cannot resolve *.vKnots")
            return nil
        }
        
        guard let controlPoints = surfaceJson["controlPoints"] as? [Any] else {
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
    
    static func parse(curveJson: [String: Any]) -> BSplineCurve? {
        guard let degree = curveJson["degree"] as? Int else {
            print("cannot resolve *.degree")
            return nil
        }
        
        guard let knots = curveJson["knots"] as? [Any] else {
            print("cannot resolve *.knots")
            return nil
        }
        guard let controlPoints = curveJson["controlPoints"] as? [Any] else {
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
