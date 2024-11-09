//
//  GordonSurface.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/26.
//

import simd
import Foundation
import SwiftUI

class GordonSurface {
    let uSections: [BSplineCurve]
    let vSections: [BSplineCurve]
    let isoV: [Float]
    let isoU: [Float]
    let intersections: [[(SIMD2<Float>, SIMD3<Float>)]]
    
    var e1: Float = 1e-6
//    var e2: Float = cos(Float.pi / 2 - Float(Angle(degrees: 1).radians))
    
    private(set) var constructionResult: ConstructionResult?
    struct ConstructionResult {
        let uLoft: BSplineSurface
        let vLoft: BSplineSurface
        let tensorProduct: BSplineSurface
        
        let gordonSurface: BSplineSurface
    }
    
    @discardableResult
    func construct() -> Bool {
        do {
            let uLoftResult = try BSplineInterpolator.loft(sections: uSections, blendParameter: .v, parameters: isoV)
            let vLoftResult = try BSplineInterpolator.loft(sections: vSections, blendParameter: .u, parameters: isoU)
            let tensorProductInterpolatees = try intersections.map { vCurveInterpolatee in
                let interpolationResult = try BSplineInterpolator.interpolate(points: vCurveInterpolatee.map { $0.1 }, parameters: isoV)
                return interpolationResult.curve
            }
            let tensorProductLoftResult = try BSplineInterpolator.loft(sections: tensorProductInterpolatees,
                                                                       blendParameter: .u,
                                                                       parameters: isoU)
            
            let uLoft = uLoftResult.surface
            let vLoft = vLoftResult.surface
            let tp = tensorProductLoftResult.surface
            
            
            let compatibleSurfaces = BSplineInterpolator.makeCompatible([uLoft, vLoft, tp])
            
            guard compatibleSurfaces.count == 3 else {
                throw PhantomError.unknown("天气预报大结局啦！")
            }
            
            var compatibleControlNet: [[SIMD4<Float>]] = compatibleSurfaces[2].controlNet
            
            for i in 0..<compatibleControlNet.count {
                for j in 0..<compatibleControlNet[i].count {
                    compatibleControlNet[i][j] = compatibleSurfaces[0].controlNet[i][j] + compatibleSurfaces[1].controlNet[i][j] - compatibleControlNet[i][j]
                }
            }
            
            let gordonSurface = BSplineSurface(uBasis: compatibleSurfaces[0].uBasis,
                                               vBasis: compatibleSurfaces[0].vBasis,
                                               controlNet: compatibleControlNet,
                                               controlPointColor: compatibleControlNet)
            
            constructionResult = ConstructionResult(uLoft: uLoft,
                                                    vLoft: vLoft,
                                                    tensorProduct: tp,
                                                    gordonSurface: gordonSurface)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    /// Initialize Gordon surface generator
    ///
    /// Assumes `uSections` and `vSections` are compatible.
    init(uSections: [BSplineCurve],
         vSections: [BSplineCurve],
         isoU: [Float],
         isoV: [Float]) throws {
        self.uSections = uSections
        self.vSections = vSections
        self.isoU = isoU
        self.isoV = isoV
        
        guard uSections.count == isoV.count
                && vSections.count == isoU.count else {
            throw PhantomError.unknown("uSections and vSections should match isoV and isoU")
        }
        
        var intersectionsAveraged: [[(SIMD2<Float>, SIMD3<Float>)]] = []
        for i in 0..<isoU.count {
            var intersectionsAveragedTemp: [(SIMD2<Float>, SIMD3<Float>)] = []
            for j in 0..<isoV.count {
                let u = isoU[i]
                let v = isoV[j]
                let vSection = vSections[i]
                let uSection = uSections[j]
                let uv = SIMD2<Float>(u, v)
                let pointOnVSection = vSection.point(at: v)!
                let pointOnUSection = uSection.point(at: u)!
                let error = distance(pointOnUSection, pointOnVSection)
                if error > e1 {
                    print("Intersection point (\(i), \(j)) has error: \(error)")
                }
                
                let point = (pointOnUSection + pointOnVSection) / 2
                intersectionsAveragedTemp.append((uv, point))
            }
            intersectionsAveraged.append(intersectionsAveragedTemp)
        }
        
        self.intersections = intersectionsAveraged
    }
}
