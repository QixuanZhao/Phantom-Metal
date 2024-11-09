//
//  PointSetConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/5.
//

import SwiftUI
import simd

struct PointSetConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor = false
    
    var body: some View {
        Button {
            showConstructor = true
        } label: {
            Label("Point Set", systemImage: "chart.dots.scatter")
        }.popover(isPresented: $showConstructor) {
            TabView {
                CurveSamplePointSetPanel(viewModel: .init(drawables: drawables))
                    .tabItem { Text("Curve Samples") }
                PlainPointSetPanel().tabItem { Text("Plain") }
                IntersectionPointPanel().tabItem { Text("Intersection") }
            }.frame(minWidth: 300, minHeight: 400).padding()
                .tabViewStyle(.grouped)
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    drawables.insert(key: "Curve 1", value: BSplineCurve())
    drawables.insert(key: "Curve 2", value: BSplineCurve())
    drawables.insert(key: "Curve 3", value: BSplineCurve())
    drawables.insert(key: "Curve 4", value: BSplineCurve())
    
    return PointSetConstructor().padding()
        .environment(drawables)
}
