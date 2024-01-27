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
    @State private var showExporter: Bool = false
    static private(set) var placeholder = DrawableItem(name: "", type: .none)
    
    struct DrawableItem: Identifiable {
        var id: String { name }
        let name: String
        let type: `Type`
        
        enum `Type`: String {
            case geometry, mesh, curve, surface, none
            static func fromDrawable(_ drawable: Phantom.Drawable) -> `Type` {
                switch drawable {
                case is Geometry: .geometry
                case is Mesh: .mesh
                case is BSplineCurve: .curve
                case is BSplineSurface: .surface
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
        HStack {
            ModelLoader()
            BSplineCurveConstructor()
            BSplineSurfaceConstructor()
        }
    }
    
    var body: some View {
        Table(of: DrawableItem.self, selection: $selected) {
            TableColumn("Name") { data in
                if data.type == .none { generatorRow }
                else { Text(data.name) }
            }
            TableColumn("Type") { data in
                if data.type != .none {
                    Text(data.type.rawValue)
                }
            }.width(ideal: 50)
        } rows: {
            ForEach (drawableTableData) { data in
                TableRow(data).contextMenu {
                    Button {
                        drawables.remove(key: data.name)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            TableRow(Self.placeholder)
        }
    }
}

#Preview {
    let collection = DrawableCollection()
    return HStack {
        DrawableTable(selected: .constant(nil))
        DrawableNameList(selected: .constant(nil))
    }
    .environment(collection)
}
