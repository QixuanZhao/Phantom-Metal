//
//  BézeirCurveControlPointItem.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import SwiftUI

struct BézeirCurveControlPointItem: View {
    @Environment(\.self) private var environment
    
    var curve: BézeirCurve
    var controlPointIndex: Int
    
    private let x: Binding<Float>
    private let y: Binding<Float>
    private let z: Binding<Float>
    private let w: Binding<Float>
    
    @State private var showPositionPanel = false
    
    var body: some View {
        Button {
            showPositionPanel = true
        } label: {
            HStack {
                Spacer()
                Text("\(controlPointIndex)")
                Image(systemName: "square.fill")
                .foregroundColor(
                    Color(.displayP3,
                          red: Double(curve.controlPointColor[controlPointIndex].x),
                          green: Double(curve.controlPointColor[controlPointIndex].y),
                          blue: Double(curve.controlPointColor[controlPointIndex].z),
                          opacity: Double(curve.controlPointColor[controlPointIndex].w)))
                Spacer()
            }
        }.frame(minWidth: 100)
        .popover(isPresented: $showPositionPanel) {
            VStack {
                HStack {
                    ColorPicker("Color",
                                selection: .init(get: { Color(.displayP3,
                                                              red: Double(curve.controlPointColor[controlPointIndex].x),
                                                              green: Double(curve.controlPointColor[controlPointIndex].y),
                                                              blue: Double(curve.controlPointColor[controlPointIndex].z),
                                                              opacity: Double(curve.controlPointColor[controlPointIndex].w)) },
                                                 set: {
                                                        let resolved = $0.resolve(in: environment)
                                                        curve.setControlPointColor(at: controlPointIndex,
                                                                                   .init(x: resolved.red,
                                                                                         y: resolved.green,
                                                                                         z: resolved.blue,
                                                                                         w: resolved.opacity))
                                                 }))
                    Spacer()
                }
                HStack {
                    Text("x").monospaced()
                    FloatPicker(value: x)
                }
                HStack {
                    Text("y").monospaced()
                    FloatPicker(value: y)
                }
                HStack {
                    Text("z").monospaced()
                    FloatPicker(value: z)
                }
                HStack {
                    Text("w").monospaced()
                    FloatPicker(value: w).disabled(true)
                }
            }.textFieldStyle(.roundedBorder).padding().frame(minWidth: 200)
        }
    }
        
    
    init(curve: BézeirCurve,
         controlPointIndex: Int) {
        self.curve = curve
        self.controlPointIndex = controlPointIndex
        
        self.x = .init(get: { curve.controlPoints[controlPointIndex].x },
                       set: { curve.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 0) })
        self.y = .init(get: { curve.controlPoints[controlPointIndex].y },
                       set: { curve.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 1) })
        self.z = .init(get: { curve.controlPoints[controlPointIndex].z },
                       set: { curve.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 2) })
        self.w = .init(get: { curve.controlPoints[controlPointIndex].w },
                       set: { curve.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 3) })
    }
}

#Preview {
    BézeirCurveControlPointItem(curve: BézeirCurve(), controlPointIndex: 0)
}
