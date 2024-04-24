//
//  BSplineCurveConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/10.
//

import SwiftUI

extension BSplineBasis.Knot: Identifiable, Equatable {
    static func == (lhs: BSplineBasis.Knot, rhs: BSplineBasis.Knot) -> Bool {
        lhs.value == rhs.value && lhs.multiplicity == rhs.multiplicity
    }
    
    var id: Float { value }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

struct BSplineCurveConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor = false
    @State private var basis: BSplineBasis = BSplineBasis(degree: 3, 
                                                          knots: [
                                                            .init(value: 0, multiplicity: 4),
                                                            .init(value: 1, multiplicity: 4)
                                                          ])
    
    var knotPanel: some View {
        VStack {
            BSplineBasisKnotEditor(basis: $basis)
            BSplineBasisChart(basis: basis).frame(height: 300).controlSize(.small)
            
            Button {
                var cp: [SIMD4<Float>] = []
                for i in 0 ..< basis.multiplicitySum - basis.order {
                    cp.append([cos(Float(i)) * Float(i), sin(Float(i)) * Float(i), Float(i), 1])
                }
                let curve = BSplineCurve(knots: basis.knots,
                                         controlPoints: cp,
                                         degree: basis.degree)
                let name = drawables.uniqueName(name: curve.name)
                curve.name = name
                drawables.insert(key: name, value: curve)
            } label: {
                HStack {
                    Spacer()
                    Text("Confirm")
                    Spacer()
                }
            }.buttonStyle(.borderedProminent)
        }.padding().frame(width: 400)
    }
    
    var body: some View {
        Button {
            showConstructor = true
        } label: {
            Label("B-Spline Curve", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        }.popover(isPresented: $showConstructor) {
            knotPanel
        }
    }
}

#Preview {
    ScrollView {
        HStack {
            BSplineCurveConstructor()
            BSplineCurveConstructor()
        }.frame(width: 300)
        .padding()
    }.environment(Renderer())
    .environment(DrawableCollection())
}
