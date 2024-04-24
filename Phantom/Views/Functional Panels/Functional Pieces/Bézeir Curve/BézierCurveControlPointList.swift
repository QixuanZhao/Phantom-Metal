//
//  BézeirCurveControlPointList.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import SwiftUI

struct BézierCurveControlPointList: View {
    var curve: BézierCurve
    
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
                BézierCurveControlPointItem(curve: curve,
                                            controlPointIndex: cp.id)
            }
        }
    }
}

#Preview {
    BézierCurveControlPointList(curve: BézierCurve())
}
