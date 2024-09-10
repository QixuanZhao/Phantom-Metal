//
//  LSFSurfaceConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/9/1.
//

import SwiftUI

struct LSFSurfaceConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor = false
    @State private var selectedPointSetName: String?
    @State private var selectedUVSetName: String?
    @State private var innerKnotCount: Int = 0
    
    private var pointSets: [TableStringItem] {
        drawables.keys.filter { drawables[$0] is PointSet }
            .map { TableStringItem(name: $0) }
    }
    
    var panel: some View {
        VStack {
            HStack {
                GroupBox {
                    Table(pointSets, selection: $selectedUVSetName) {
                        TableColumn("Name") { Text($0.name) }
                    }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                } label: {
                    Text("UV Set")
                }
                
                GroupBox {
                    Table(pointSets, selection: $selectedPointSetName) {
                        TableColumn("Name") { Text($0.name) }
                    }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                } label: {
                    Text("Point Set")
                }
            }
            
            Stepper("Inner Knot Count \(innerKnotCount)", value: $innerKnotCount)
            
            Button {
                if let selectedPointSetName,
                   let selectedUVSetName {
                    
                    let points = drawables[selectedPointSetName] as! PointSet
                    let uvs = drawables[selectedUVSetName] as! PointSet
                    
                    var samples: [(SIMD2<Float>, SIMD3<Float>)] = []
                    for i in 0..<points.points.count {
                        let uv = SIMD2<Float>(uvs.points[i].x, uvs.points[i].y)
                        let p = points.points[i]
                        samples.append((uv, p))
                    }
                    
                    var knots: [BSplineBasis.Knot] = [
                        .init(value: 0, multiplicity: 4),
                        .init(value: 1, multiplicity: 4)
                    ]
                    
                    if innerKnotCount > 0 {
                        for i in 0..<innerKnotCount {
                            let knotValue = Float(i + 1) / Float(innerKnotCount + 1)
                            knots.insert(.init(value: knotValue, multiplicity: 1), at: 1 + i)
                        }
                    }
                    
                    let resultSurface = try? BSplineApproximator.approximate(
                        samples: samples,
                        uBasis: .init(degree: 3, knots: knots),
                        vBasis: .init(degree: 3, knots: knots)
                    )
                    
                    if let resultSurface {
                        resultSurface.name = drawables.uniqueName(name: "LSF Surf")
                        drawables.insert(key: resultSurface.name, value: resultSurface)
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Fit")
                    Spacer()
                }
            }.disabled(selectedPointSetName == nil || selectedUVSetName == nil || selectedPointSetName == selectedUVSetName)
        }.frame(minWidth: 300).padding()
    }
    
    var body: some View {
        Button {
            showConstructor.toggle()
        } label: {
            Label("Guide", systemImage: "tray")
        }.popover(isPresented: $showConstructor) {
            panel
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    drawables.insert(key: "What", value: PointSet(points: [.zero]))
    drawables.insert(key: "Ever", value: PointSet(points: [.zero]))
    drawables.insert(key: "You", value: PointSet(points: [.zero]))
    
    return LSFSurfaceConstructor().padding()
        .environment(drawables)
}
