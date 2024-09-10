//
//  PointSetProperties.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/4/29.
//

import SwiftUI

struct PointSetProperties: View {
    @Environment(\.self) private var environment
//    @Environment(DrawableCollection.self) private var drawables
    
    var pointSet: PointSet
    var pointItems: [IndexedTableStringItem] = []
    
    @State private var selectedPointIndex: Int?
    @State private var pointSetColor: Color
    
    var body: some View {
        ColorPicker("Color", selection: $pointSetColor)
            .onChange(of: pointSetColor) {
                let resolvedColor = pointSetColor.resolve(in: environment)
                pointSet.setColor(.init(resolvedColor.red, resolvedColor.green, resolvedColor.blue, resolvedColor.opacity))
            }
        Table(of: IndexedTableStringItem.self, selection: $selectedPointIndex) {
            TableColumn("#") { item in
                Text("\(item.id)").monospacedDigit()
            }.width(20)
            TableColumn("Position") { item in
                Text(item.name).monospacedDigit()
            }
        } rows: {
            ForEach(pointItems) { item in
                TableRow(item)
            }
        }
    }
    
    init(pointSet: PointSet) {
        self.pointSet = pointSet
        pointItems = pointSet.points.enumerated().map { (index, point) in
            IndexedTableStringItem(id: index, name: "\(point.x), \(point.y), \(point.z)")
        }
        
        let color = Color(red: Double(pointSet.color.x),
                          green: Double(pointSet.color.y),
                          blue: Double(pointSet.color.z),
                          opacity: Double(pointSet.color.w))
        _pointSetColor = State(initialValue: color)
    }
}

#Preview {
    PointSetProperties(pointSet: PointSet(points: [
        SIMD3<Float>.zero,
        SIMD3<Float>(1, 1, 1),
        SIMD3<Float>(1, 2, 1),
        SIMD3<Float>(1, 1, 3)
    ])).environment(DrawableCollection())
}
