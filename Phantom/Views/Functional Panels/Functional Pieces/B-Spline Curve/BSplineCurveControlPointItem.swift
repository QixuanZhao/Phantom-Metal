//
//  BSplineCurveControlPointItem.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/15.
//

import SwiftUI

struct BSplineCurveControlPointItem: View {
    @Environment(\.self) private var environment
    
    var curve: BSplineCurve
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
                    Color(red: Double(curve.controlPointColor[controlPointIndex].x),
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
                                selection: .init(get: { Color(red: Double(curve.controlPointColor[controlPointIndex].x),
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
        
    
    init(curve: BSplineCurve,
         controlPointIndex: Int) {
        self.curve = curve
        self.controlPointIndex = controlPointIndex
        
        let realCount = curve.controlPoints.count
        if controlPointIndex >= realCount {
            self.x = .constant(0)
            self.y = .constant(0)
            self.z = .constant(0)
            self.w = .constant(0)
            return
        }
        
        self.x = .init(get: {
            if controlPointIndex < curve.controlPoints.count {
                curve.controlPoints[controlPointIndex].x
            } else { 0 }
        }, set: { curve.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 0) })
        
        self.y = .init(get: {
            if controlPointIndex < curve.controlPoints.count {
                curve.controlPoints[controlPointIndex].y
            } else { 0 }
        }, set: { curve.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 1) })
        self.z = .init(get: {
            if controlPointIndex < curve.controlPoints.count {
                curve.controlPoints[controlPointIndex].z
            } else { 0 }
        }, set: { curve.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 2) })
        self.w = .init(get: {
            if controlPointIndex < curve.controlPoints.count {
                curve.controlPoints[controlPointIndex].w
            } else { 0 }
        }, set: { curve.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 3) })
    }
}

extension BSplineCurveControlPointItem {
    @Observable
    class ViewModel {
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        var w: Float = 0
        
        var curve: BSplineCurve?
        var controlPointIndex: Int?
    }
}

#Preview {
    BSplineCurveControlPointItem(curve: BSplineCurve(),
                                 controlPointIndex: 1)
}
