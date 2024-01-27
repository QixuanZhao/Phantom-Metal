//
//  BSplineCurveProperties.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/14.
//

import SwiftUI

struct BSplineCurveProperties: View {
    var curve: BSplineCurve
    
    @State private var showControlPoints: Bool = true
    @State private var newKnot: Float = 0.5
    
    var body: some View {
        VStack {
            GroupBox {
                VStack {
                    HStack {
                        Text("New Knot")
                        FloatPicker(value: $newKnot)
                        Button {
                            curve.insert(knot: newKnot)
                        } label: {
                            Text("insert")
                        }
                    }.controlSize(.small)
                    BSplineBasisChart(basis: curve.basis).frame(height: 200).controlSize(.mini)
                }
            } label: {
                HStack {
                    Text("Basis")
                    Spacer()
                }
            }
            
            GroupBox {
                BSplineCurveControlPointList(curve: curve).frame(minHeight: 150)
            } label: {
                HStack {
                    Text("Control Points")
                    Toggle(isOn: .init(get: { curve.showControlPoints },
                                       set: { value in curve.showControlPoints = value })) {
                        Label("Show", systemImage: curve.showControlPoints ? "eye.fill" : "eye.slash.fill")
                    }.toggleStyle(.button).labelStyle(.iconOnly)
                }
            }
        }
    }
    
    init(curve: BSplineCurve) {
        self.curve = curve
    }
}

#Preview {
    BSplineCurveProperties(curve: BSplineCurve())
}
