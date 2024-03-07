//
//  BézeirCurveConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import SwiftUI

struct BézeirCurveConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor = false
    @State private var basis: BernsteinBasis = BernsteinBasis(degree: 3)
    
    private let debounceInterval: Double = 0.5
    @State private var performTimestamp: Date = .now
 
    var body: some View {
        Button {
            showConstructor = true
        } label: {
            Label("Bézeir Curve", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
        }.popover(isPresented: $showConstructor) {
            VStack {
                VStack {
                    Text("Degree: \(basis.degree)").monospacedDigit()
                    HStack {
                        Slider(value: .init(get: { Double(basis.degree) }, set: { basis.degree = Int($0) }),
                               in: 1...16, step: 1,
                               label: { Text("") },
                               minimumValueLabel: { Text("1") },
                               maximumValueLabel: { Text("16") })
                        Stepper("", value: $basis.degree, in: 1...16, step: 1)
                    }
                }.onChange(of: basis.degree) {
                    performTimestamp = .now + debounceInterval
                    
                    Timer.scheduledTimer(withTimeInterval: debounceInterval,
                                         repeats: false) { _ in
                        if Date.now >= performTimestamp {
                            basis.recreateTexture()
                        }
                    }
                }
                BernsteinBasisChart(basis: basis).frame(height: 300).controlSize(.small)
                
                Button {
                    var cp: [SIMD4<Float>] = []
                    for i in 0 ... basis.degree {
                        cp.append([cos(Float(i)) * Float(i), sin(Float(i)) * Float(i), Float(i), 1])
                    }
                    
                    let curve = BézeirCurve(controlPoints: cp, degree: basis.degree)
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
            }.padding().frame(width: 350)
        }
    }
}

#Preview {
    BézeirCurveConstructor()
        .environment(DrawableCollection())
}
