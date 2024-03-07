//
//  BézeirCurveControlPointList.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import SwiftUI

struct BézeirCurveControlPointList: View {
    var curve: BézeirCurve
    
    struct ControlPoint: Identifiable {
        var id: Int
    }
    
    var controlPoints: [ControlPoint] {
        var result: [ControlPoint] = []
        for i in 0..<curve.controlPoints.count {
            result.append(ControlPoint(id: i))
        }
        return result
    }
    
    var body: some View {
        ScrollView (showsIndicators: true) {
            ForEach(controlPoints) { cp in
                BézeirCurveControlPointItem(curve: curve,
                                            controlPointIndex: cp.id)
            }
        }
    }
}

#Preview {
    BézeirCurveControlPointList(curve: BézeirCurve())
}
