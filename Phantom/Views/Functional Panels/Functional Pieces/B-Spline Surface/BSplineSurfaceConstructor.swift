//
//  BSplineSurfaceConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/17.
//

import SwiftUI

struct BSplineSurfaceConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor = false
    @State private var uBasis: BSplineBasis = BSplineBasis(degree: 3,
                                                          knots: [
                                                            .init(value: 0, multiplicity: 4),
                                                            .init(value: 1, multiplicity: 4)
                                                          ])
    @State private var vBasis: BSplineBasis = BSplineBasis(degree: 3,
                                                          knots: [
                                                            .init(value: 0, multiplicity: 4),
                                                            .init(value: 1, multiplicity: 4)
                                                          ])
    
    var knotPanel: some View {
        VStack {
            HStack {
                GroupBox("U Knots") {
                    BSplineBasisKnotEditor(basis: $uBasis)
                    BSplineBasisChart(basis: uBasis).frame(height: 300)
                }
                GroupBox("V Knots") {
                    BSplineBasisKnotEditor(basis: $vBasis)
                    BSplineBasisChart(basis: vBasis).frame(height: 300)
                }
            }
            
            Button {
                var controlPoints: [[SIMD4<Float>]] = []
                for j in 0 ..< vBasis.multiplicitySum - vBasis.order {
                    let y = Float(j) - Float(vBasis.multiplicitySum - vBasis.order - 1) / 2
                    var iPoints: [SIMD4<Float>] = []
                    for i in 0 ..< uBasis.multiplicitySum - uBasis.order {
                        let x = Float(i) - Float(uBasis.multiplicitySum - uBasis.order - 1) / 2
                        iPoints.append([x, y, sin(x + y * x), 1])
                    }
                    controlPoints.append(iPoints)
                }
                let surface = BSplineSurface(uKnots: uBasis.knots, vKnots: vBasis.knots, degrees: (uBasis.degree, vBasis.degree),
                                             controlNet: controlPoints)
                let name = drawables.uniqueName(name: surface.name)
                surface.name = name
                drawables.insert(key: name, value: surface)
            } label: {
                HStack {
                    Spacer()
                    Text("Confirm")
                    Spacer()
                }
            }.buttonStyle(.borderedProminent)
        }.padding().frame(width: 800)
    }
    
    var body: some View {
        Button {
            showConstructor = true
        } label: {
            Label("B-Spline Surface", systemImage: "skew")
        }.popover(isPresented: $showConstructor) {
            knotPanel
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    
    return BSplineSurfaceConstructor().environment(drawables)
}
