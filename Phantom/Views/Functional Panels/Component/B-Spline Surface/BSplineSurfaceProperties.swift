//
//  BSplineSurfaceProperties.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/18.
//

import SwiftUI

struct BSplineSurfaceProperties: View {
    var surface: BSplineSurface
    
    let tessellationFactor: Binding<Float>
    @State private var newUKnot: Float = 0.5
    @State private var newVKnot: Float = 0.5
    
    var body: some View {
        VStack {
            HStack {
                VStack (spacing: .zero) {
                    Text("Tessellation Factor: \(Int(surface.edgeTessellationFactors.x))").font(.caption)
                    Slider(value: tessellationFactor,
                           in: 1...64, step: 1,
                           label: { Text("") },
                           minimumValueLabel: { Text("1") },
                           maximumValueLabel: { Text("64") })
                }
                Stepper("", value: tessellationFactor,
                        in: 1...64, step: 1)
            }
            
            ScrollView (.horizontal) {
                HStack {
                    GroupBox ("U Basis") {
                        VStack {
                            HStack {
                                Text("New Knot")
                                FloatPicker(value: $newUKnot)
                                Button {
                                    surface.insert(uKnot: newUKnot)
                                } label: {
                                    Text("Insert")
                                }
                            }
                            BSplineBasisChart(basis: surface.uBasis).frame(width: 240, height: 200).controlSize(.mini)
                        }
                    }
                    GroupBox ("V Basis") {
                        VStack {
                            HStack {
                                Text("New Knot")
                                FloatPicker(value: $newVKnot)
                                Button {
                                    surface.insert(vKnot: newVKnot)
                                } label: {
                                    Text("Insert")
                                }
                            }
                            BSplineBasisChart(basis: surface.vBasis).frame(width: 240, height: 200).controlSize(.mini)
                        }
                    }
                }
            }
            
            GroupBox {
                BSplineSurfaceControlPointMatrix(surface: surface).frame(minHeight: 150)
            } label: {
                HStack {
                    Text("Control Points")
                    Toggle(isOn: .init(get: { surface.showControlNet }, 
                                       set: { show in surface.showControlNet = show })) {
                        Label("Show", systemImage: surface.showControlNet ? "eye.fill" : "eye.slash.fill")
                    }.toggleStyle(.button).labelStyle(.iconOnly)
                }
            }
        }
    }
    
    init(surface: BSplineSurface) {
        self.surface = surface
        self.tessellationFactor = .init(get: { surface.edgeTessellationFactors.x },
                                        set: { value in
                                            surface.edgeTessellationFactors = .init(repeating: value)
                                            surface.insideTessellationFactors = .init(repeating: value)
                                        })
    }
}

#Preview {
    BSplineSurfaceProperties(surface: BSplineSurface())
}
