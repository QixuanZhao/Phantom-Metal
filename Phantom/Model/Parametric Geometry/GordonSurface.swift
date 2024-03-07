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
    let originalUSections: [BSplineCurve]
    let originalVSections: [BSplineCurve]
    let guideCurves: [BSplineCurve]
    
    var e1: Float = 1e-6
    var e2: Float = cos(Float.pi / 2 - Float(Angle(degrees: 1).radians))
    var sampleCount: Int = 100
    var maxIteration: Int = 100
    
    let preprocessResult: PreprocessResult
    struct PreprocessResult {
        let uSections: [BSplineCurve]
        let vSections: [BSplineCurve]
        
        let isoV: [Float]
        let isoU: [Float]
        
        let intersections: [[(SIMD2<Float>, SIMD3<Float>)]]
    }
    
    private(set) var constructionResult: GordonSurfaceConstructionResult?
    struct GordonSurfaceConstructionResult {
        let uLoft: BSplineSurface
        let vLoft: BSplineSurface
        let tensorProduct: BSplineSurface
        
        let gordonSurface: BSplineSurface
    }
    
    private(set) var guideResult: GuideResult = .init()
    struct GuideResult {
        var surfaces: [BSplineSurface] = []
        var projectionResult: [[ProjectionResult]] = []
        var error: [GuidanceError] = []
    }
    
    /**
     * guide the construction result surface (i.e. the gordon surface or its last guided version) for N times
     * if gordon surface hasn't been constructed then return false, else return true
     * N times guidances are guaranteed when first gordon surface exists.
     */
    @discardableResult
    func guide(times N: Int = 1) -> Bool {
        guard let gordonSurface = constructionResult?.gordonSurface else { return false }
        guard !guideCurves.isEmpty else { return false }
        
        var surface = guideResult.surfaces.isEmpty ? gordonSurface : guideResult.surfaces.last!
        
        do {
            for _ in 0..<N {
                let guidanceResult = try BSplineApproximator.guide(originalSurface: surface, samples: guideResult.projectionResult.last!.map { ($0.parameters, $0.point) },
                                                                   isoU: preprocessResult.isoU, isoV: preprocessResult.isoV)
                surface = guidanceResult.modifiedSurface
                
                let projectionResult = guideCurves.flatMap { curve in
                    surface.project(curve, sampleCount: sampleCount, e1: e1, e2: e2, maxIteration: maxIteration)
                }
                
                let errors = projectionResult.map { distance($0.projectedPoint, $0.point) }.sorted()
                let maxError = errors.last!
                let minError = errors.first!
                
                var meanError: Float = 0
                errors.forEach { meanError = meanError + $0 }
                meanError = meanError / Float(errors.count)
                
                guideResult.surfaces.append(surface)
                guideResult.projectionResult.append(projectionResult)
                guideResult.error.append(GuidanceError(maxError: maxError, minError: minError, meanError: meanError))
            }
            
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    @discardableResult
    func construct() -> Bool {
        do {
            let uLoftResult = try BSplineInterpolator.loft(sections: preprocessResult.uSections, blendParameter: .v, parameters: preprocessResult.isoV)
            let vLoftResult = try BSplineInterpolator.loft(sections: preprocessResult.vSections, blendParameter: .u, parameters: preprocessResult.isoU)
            let tensorProductInterpolatees = try preprocessResult.intersections.map { vCurveInterpolatee in
                let interpolationResult = try BSplineInterpolator.interpolate(points: vCurveInterpolatee.map { $0.1 }, parameters: preprocessResult.isoV)
                return interpolationResult.curve
            }
            let tensorProductLoftResult = try BSplineInterpolator.loft(sections: tensorProductInterpolatees,
                                                                       blendParameter: .u,
                                                                       parameters: preprocessResult.isoU)
            
            let uLoft = uLoftResult.surface
            let vLoft = vLoftResult.surface
            let tp = tensorProductLoftResult.surface
            
            
            let compatibleSurfaces = BSplineInterpolator.makeCompatible([uLoft, vLoft, tp])
            
            guard compatibleSurfaces.count == 3 else {
                throw PhantomError.unknownError("The weather program reaches its end episode.")
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
            
            constructionResult = GordonSurfaceConstructionResult(uLoft: uLoft, vLoft: vLoft, 
                                                                              tensorProduct: tp,
                                                                              gordonSurface: gordonSurface)
            guideResult.error = []
            guideResult.surfaces = []
            guideResult.projectionResult = [guideCurves.flatMap { curve in
                gordonSurface.project(curve, sampleCount: sampleCount, e1: e1, e2: e2, maxIteration: maxIteration)
            }]
            
            let errors = guideResult.projectionResult.last!.map { distance($0.projectedPoint, $0.point) }.sorted()
            let maxError = errors.last!
            let minError = errors.first!
            
            var meanError: Float = 0
            errors.forEach { meanError = meanError + $0 }
            meanError = meanError / Float(errors.count)
            
            guideResult.error.append(GuidanceError(maxError: maxError, minError: minError, meanError: meanError))

            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    init(originalUSections: [BSplineCurve],
         originalVSections: [BSplineCurve],
         guideCurves: [BSplineCurve]) {
        self.originalUSections = originalUSections
        self.originalVSections = originalVSections
        self.guideCurves = guideCurves
        
        let isoV = BSplineInterpolator.evaluateParametersByChordLength(for: originalUSections)
        let isoU = BSplineInterpolator.evaluateParametersByChordLength(for: originalVSections)
        
        var uSectionsStartValueCandidates = originalUSections.map { $0.generateStartValueCandidates() }
        var vSectionsStartValueCandidates = originalVSections.map { $0.generateStartValueCandidates() }
        
        let orientedUSections = originalUSections.enumerated().map { (i, section) in
            let pStart = BSplineCurve.nearestParameter(section, originalVSections.first!,
                                                       startValueCandidatesA: uSectionsStartValueCandidates[i],
                                                       startValueCandidatesB: vSectionsStartValueCandidates.first!)
            let startParameter = pStart.0
            
            let pEnd = BSplineCurve.nearestParameter(section, originalVSections.last!,
                                                     startValueCandidatesA: uSectionsStartValueCandidates[i],
                                                     startValueCandidatesB: vSectionsStartValueCandidates.last!)
            let endParameter = pEnd.0
            
            if startParameter > endParameter {
                let reversedSection = section.reversed()
                uSectionsStartValueCandidates[i] = reversedSection.generateStartValueCandidates()
                return reversedSection
            } else { return section }
        }
        
        let orientedVSections = originalVSections.enumerated().map { (j, section) in
            let pStart = BSplineCurve.nearestParameter(section, orientedUSections.first!,
                                                       startValueCandidatesA: vSectionsStartValueCandidates[j],
                                                       startValueCandidatesB: uSectionsStartValueCandidates.first!)
            let startParameter = pStart.0
            
            let pEnd = BSplineCurve.nearestParameter(section, orientedUSections.last!,
                                                     startValueCandidatesA: vSectionsStartValueCandidates[j],
                                                     startValueCandidatesB: uSectionsStartValueCandidates.last!)
            let endParameter = pEnd.0
            
            if startParameter > endParameter {
                let reversedSection = section.reversed()
                vSectionsStartValueCandidates[j] = reversedSection.generateStartValueCandidates()
                return reversedSection
            } else { return section }
        }
        
        var intersections: [[(SIMD2<Float>, SIMD3<Float>)]] = []
        for (j, vSection) in orientedVSections.enumerated() {
            var intersectionsOnVSection: [(SIMD2<Float>, SIMD3<Float>)] = []
            for (i, uSection) in orientedUSections.enumerated() {
                let projectionResult = BSplineCurve.nearestParameter(vSection, uSection,
                                                                     startValueCandidatesA: vSectionsStartValueCandidates[j],
                                                                     startValueCandidatesB: uSectionsStartValueCandidates[i])
                
                let parameters = SIMD2<Float>(projectionResult.0, projectionResult.1)
                let pointOnVSection = vSection.point(at: parameters[0])!
                let pointOnUSection = uSection.point(at: parameters[1])!
                let point = (pointOnUSection + pointOnVSection) / 2
                intersectionsOnVSection.append((parameters, point))
            }
            intersections.append(intersectionsOnVSection)
        }
        
        let alignedUSections = orientedUSections.enumerated().map { (i, section) in
            let nodes = (0..<orientedVSections.count).map { j in
                intersections[j][i]
            }
            
            var innerNodeParameter = nodes.map { $0.0[1] }
            innerNodeParameter.removeFirst()
            innerNodeParameter.removeLast()
            
            var innerIsoU = isoU
            innerIsoU.removeFirst()
            innerIsoU.removeLast()
            
            if innerIsoU.isEmpty {
                return section.reparameterized(into: isoU.first! ... isoU.last!)!
            } else {
                return BSplineCurve.combine(curves: section.split(at: innerNodeParameter),
                                            domainStart: isoU.first!,
                                            domainJoints: innerIsoU,
                                            domainEnd: isoU.last!)!
            }
        }
        
        let alignedVSections = orientedVSections.enumerated().map { (j, section) in
            let nodes = (0..<orientedUSections.count).map { i in
                intersections[j][i]
            }
            
            var innerNodeParameter = nodes.map { $0.0[0] }
            innerNodeParameter.removeFirst()
            innerNodeParameter.removeLast()
            
            var innerIsoV = isoV
            innerIsoV.removeFirst()
            innerIsoV.removeLast()
            
            if innerIsoV.isEmpty {
                return section.reparameterized(into: isoV.first! ... isoV.last!)!
            } else {
                return BSplineCurve.combine(curves: section.split(at: innerNodeParameter),
                                            domainStart: isoV.first!,
                                            domainJoints: innerIsoV,
                                            domainEnd: isoV.last!)!
            }
        }
        
        self.preprocessResult = PreprocessResult(uSections: alignedUSections,
                                                 vSections: alignedVSections,
                                                 isoV: isoV, isoU: isoU,
                                                 intersections: intersections)
    }
}
