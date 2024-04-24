//
//  BézeirCurveProperties.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import SwiftUI

struct BézierCurveProperties: View {
    var curve: BézierCurve
    
    var body: some View {
        VStack {
            GroupBox {
                BernsteinBasisChart(basis: curve.basis).frame(height: 200).controlSize(.mini)
            } label: {
                Text("Basis")
            }
            
            GroupBox {
                BézierCurveControlPointList(curve: curve).frame(minHeight: 150)
            } label: {
                HStack {
                    Text("Control Points")
                    Toggle(isOn: .init(get: { curve.showControlPoints },
                                       set: { value in curve.showControlPoints = value })) {
                        Label("Show", systemImage: curve.showControlPoints ? "eye.fill" : "eye.slash.fill")
                    }.toggleStyle(.button).labelStyle(.iconOnly).buttonStyle(.plain)
                }
            }
        }
    }
    
    init(curve: BézierCurve) {
        self.curve = curve
    }
}

#Preview {
    BézierCurveProperties(curve: BézierCurve())
}
