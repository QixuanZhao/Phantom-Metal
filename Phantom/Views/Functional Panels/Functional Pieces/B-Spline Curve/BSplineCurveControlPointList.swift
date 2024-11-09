//
//  BSplineCurveControlPointList.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/14.
//

import SwiftUI

struct BSplineCurveControlPointList: View {
    var curve: BSplineCurve
    
    struct ControlPoint: Identifiable {
        var xyzw: [Float]
        var id: Int
    }
    
    var controlPoints: [ControlPoint] {
        var result: [ControlPoint] = []
        for i in 0..<curve.controlPoints.count {
            result.append(ControlPoint(xyzw: [curve.controlPoints[i].x,
                                              curve.controlPoints[i].y,
                                              curve.controlPoints[i].z,
                                              curve.controlPoints[i].w],
                                       id: i))
        }
        return result
    }
    
    var body: some View {
        ScrollView (showsIndicators: true) {
            ForEach(controlPoints) { cp in
                BSplineCurveControlPointItem(curve: curve,
                                             controlPointIndex: cp.id)
            }
        }
    }
}

@Observable
class BSplineCurveControlPointListModel {
    
}

#Preview {
    BSplineCurveControlPointList(curve: BSplineCurve())
}
