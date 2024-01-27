//
//  BSplineSurfaceControlPointItem.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/18.
//

import SwiftUI

struct BSplineSurfaceControlPointItem: View {
    var surface: BSplineSurface
    var controlPointIndex: (Int, Int)
    
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
                Text("\(controlPointIndex.1), \(controlPointIndex.0)").font(.caption)
                Spacer()
            }
        }
        .popover(isPresented: $showPositionPanel) {
            VStack {
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
    
    init(surface: BSplineSurface,
         controlPointIndex: (Int, Int)) {
        self.surface = surface
        self.controlPointIndex = controlPointIndex
        
        x = .init(get: { surface.controlNet[controlPointIndex.0][controlPointIndex.1].x },
                  set: { surface.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 0) })
        y = .init(get: { surface.controlNet[controlPointIndex.0][controlPointIndex.1].y },
                  set: { surface.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 1) })
        z = .init(get: { surface.controlNet[controlPointIndex.0][controlPointIndex.1].z },
                  set: { surface.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 2) })
        w = .init(get: { surface.controlNet[controlPointIndex.0][controlPointIndex.1].w },
                  set: { surface.setControlPointComponent(at: controlPointIndex, $0, componentIndex: 3) })
    }
}

#Preview {
    BSplineSurfaceControlPointItem(surface: BSplineSurface(), controlPointIndex: (0, 0))
}
