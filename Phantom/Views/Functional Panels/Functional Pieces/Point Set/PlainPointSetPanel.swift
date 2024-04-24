//
//  PlainPointSetPanel.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/29.
//

import SwiftUI

struct PlainPointSetPanel: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var newPointX: Float = 0
    @State private var newPointY: Float = 0
    @State private var newPointZ: Float = 0
    
    @State private var pointSet: [SIMD3<Float>] = []
    
    var pointSetTableItem: [IndexedTableStringItem] {
        pointSet.enumerated().map {
            IndexedTableStringItem(id: $0.offset, name: "\($0.element.x), \($0.element.y), \($0.element.z)")
        }
    }
    
    var body: some View {
        VStack {
            Grid (alignment: .leading, verticalSpacing: .zero) {
                GridRow {
                    TextField(value: $newPointX, format: .number, prompt: Text("input x")) {
                        Text("X")
                    }
                    Text("X: \(newPointX)")
                }
                GridRow {
                    TextField(value: $newPointY, format: .number, prompt: Text("input y")) {
                        Text("Y")
                    }
                    Text("Y: \(newPointY)")
                }
                GridRow {
                    TextField(value: $newPointZ, format: .number, prompt: Text("input z")) {
                        Text("Z")
                    }
                    Text("Z: \(newPointZ)")
                }
            }.monospacedDigit()
            Button {
                pointSet.append([newPointX, newPointY, newPointZ])
            } label: {
                HStack {
                    Spacer()
                    Text("Add (\(newPointX), \(newPointY), \(newPointZ))")
                    Spacer()
                }
            }.monospacedDigit()
            
            Table(pointSetTableItem) {
                TableColumn("#") {
                    Text("\($0.id)")
                }.width(30)
                TableColumn("Spatial Coordinates") {
                    Text("\($0.name)")
                }
                TableColumn("Operation") { item in
                    Button {
                        pointSet.remove(at: item.id)
                    } label: { 
                        Label("Delete", systemImage: "minus")
                            .foregroundStyle(Color.pink).labelStyle(.iconOnly)
                    }.buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            
            HStack {
                Button {
                    pointSet.removeAll()
                } label: {
                    Label("Delete All", systemImage: "trash")
                }
                Button {
                    let ps = PointSet(points: pointSet)
                    ps.name = drawables.uniqueName(name: "Point Set")
                    drawables.insert(key: ps.name, value: ps)
                } label: {
                    HStack {
                        Spacer()
                        Label("Comfirm", systemImage: "checkmark")
                        Spacer()
                    }
                }.buttonStyle(.borderedProminent)
                    .disabled(pointSet.isEmpty)
            }
        }.textFieldStyle(.roundedBorder)
    }
}

#Preview {
    PlainPointSetPanel()
        .environment(DrawableCollection())
        .padding()
}
