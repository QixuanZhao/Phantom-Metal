//
//  BSplineSurfaceControlPointMatrix.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/18.
//

import SwiftUI

struct BSplineSurfaceControlPointMatrix: View {
    var surface: BSplineSurface
    
    struct ControlPointIndex: Identifiable {
        var id: Int
    }
    
    let iControlPointCount: Int
    let jControlPointCount: Int
    
    var iConrolPointIndices: [ControlPointIndex] {
        var result: [ControlPointIndex] = []
        for i in 0..<iControlPointCount { result.append(ControlPointIndex(id: i)) }
        return result
    }
    
    var jConrolPointIndices: [ControlPointIndex] {
        var result: [ControlPointIndex] = []
        for j in 0..<jControlPointCount { result.append(ControlPointIndex(id: j)) }
        return result
    }
    
    var body: some View {
        ScrollView ([.horizontal, .vertical]) {
            Grid {
                ForEach(jConrolPointIndices) { j in
                    GridRow {
                        ForEach(iConrolPointIndices) { i in
                            BSplineSurfaceControlPointItem(surface: surface,
                                                           controlPointIndex: (j.id, i.id))
                        }
                    }
                }
            }
        }
    }
    
    init(surface: BSplineSurface) {
        self.surface = surface
        self.iControlPointCount = surface.uBasis.multiplicitySum - surface.uBasis.order
        self.jControlPointCount = surface.vBasis.multiplicitySum - surface.vBasis.order
    }
}

#Preview {
    BSplineSurfaceControlPointMatrix(surface: BSplineSurface())
}
