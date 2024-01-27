//
//  SceneGraphView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/25.
//

import SwiftUI

struct SceneNodeView: View {
    var node: SceneNode
    
    var body: some View {
        GroupBox(label: Label(node.name, systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")) {
            Text("UUID: \(node.id)")
            Toggle(isOn: node.showAxes) {
                Label("Show Axes", systemImage: "eye\(node.showAxes ? "" : ".slash")")
            }
            DisclosureGroup(node.name) {
                Text("F")
            }
        }
        .toggleStyle(.switch)
    }
}

#Preview {
    SceneNodeView(node: .constant(SceneNode(name: "Whatever")))
}
