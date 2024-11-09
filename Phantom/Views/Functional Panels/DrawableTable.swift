//
//  DrawableList.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/29.
//

import SwiftUI

struct DrawableNameList: View {
    @Environment(DrawableCollection.self) private var drawables
    @Binding var selected: String?
    
    typealias DrawableItem = DrawableTable.DrawableItem
    
    var drawableTableData: [DrawableItem] {
        drawables.keys.map { key in
            DrawableItem(name: key,
                         type: .fromDrawable(drawables[key]!))
        }
    }
    
    var body: some View {
        Table(of: DrawableItem.self, selection: $selected) {
            TableColumn("Name") { data in
                Text(data.name)
            }
            TableColumn("Type") { data in
                Text(data.type.rawValue)
            }.width(ideal: 50)
        } rows: {
            ForEach (drawableTableData) { data in
                TableRow(data)
            }
        }
    }
}

struct DrawableTable: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @Binding var selected: String?
    static private(set) var placeholder = DrawableItem(name: "", type: .none)
    
    struct DrawableItem: Identifiable {
        var id: String { name }
        let name: String
        let type: `Type`
        
        enum `Type`: String {
            case geometry, mesh
            case lineSegments = "line segments"
            case pointSet = "point set"
            case bézeirCurve = "Bézeir curve"
            case BSplineCurve = "B-spline curve"
            case BSplineSurface = "B-spline surface"
            case none
            static func fromDrawable(_ drawable: Phantom.Drawable) -> `Type` {
                switch drawable {
                case is Geometry: .geometry
                case is Mesh: .mesh
                case is PointSet: .pointSet
                case is LineSegments: .lineSegments
                case is BSplineCurve: .BSplineCurve
                case is BézierCurve: .bézeirCurve
                case is BSplineSurface: .BSplineSurface
                default: .none
                }
            }
        }
    }
    
    var drawableTableData: [DrawableItem] {
        drawables.keys.map { key in
            DrawableItem(name: key, 
                         type: .fromDrawable(drawables[key]!))
        }
    }
    
    var generatorRow: some View {
        Grid (alignment: .leading, verticalSpacing: 5) {
            GridRow {
                ModelLoader()
                PointSetConstructor()
                BézierCurveConstructor()
                BSplineCurveConstructor()
                BSplineInterpolatedCurveConstructor()
                BSplineSurfaceConstructor()
            }
            GridRow {
                LoftedSurfaceConstructor()
                GordonSurfaceConstructor()
                LowGordonSurfaceConstructor()
                GuidedSurfaceConstructor()
                LSFSurfaceConstructor()
                CurveNetworkExtractionView()
            }
        }.labelStyle(.iconOnly)
    }
    
    var body: some View {
        VStack (spacing: .zero) {
            Table(of: DrawableItem.self, selection: $selected) {
                TableColumn("Name") { data in
                    Text(data.name)
                }.width(min: 110)
                TableColumn("Type") { data in
                    Text(data.type.rawValue)
                }.width(ideal: 50)
            } rows: {
                ForEach (drawableTableData) { data in
                    TableRow(data).contextMenu {
                        Button {
                            drawables.remove(key: data.name)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            generatorRow
                .lineLimit(1)
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondary)
                .padding()
        }
    }
}

#Preview {
    let collection = DrawableCollection()
    collection.insert(key: "B-Spline Curve", value: BSplineCurve())
    collection.insert(key: "Surface", value: BSplineSurface())
    return HSplitView {
        DrawableTable(selected: .constant(nil))
        DrawableNameList(selected: .constant(nil))
    }
    .environment(collection)
}
