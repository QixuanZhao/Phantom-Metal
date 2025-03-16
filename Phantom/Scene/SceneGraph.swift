//
//  SceneGraph.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/25.
//

import SwiftUI

@MainActor
@Observable
class SceneGraph {
    var root: SceneNode
    
    init(root: SceneNode = SceneNode(name: "Scene")) {
        root.showAxes = true
        self.root = root
    }
}
