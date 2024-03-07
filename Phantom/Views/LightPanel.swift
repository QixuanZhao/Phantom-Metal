//
//  LightPanel.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/28.
//

import SwiftUI

struct LightPanel: View {
    @Environment(Renderer.self) private var renderer: Renderer
    
    var body: some View {
        Grid (alignment: .leadingFirstTextBaseline) {
            GridRow {
                Text("Intensity")
                Slider(value: .init(get: { renderer.light.intensity },
                                    set: { renderer.light.intensity = $0 }),
                       in: 0...5)
            }
            
            GridRow {
                Text("Ambient")
                Slider(value: .init(get: { renderer.light.ambient },
                                    set: { renderer.light.ambient = $0 }),
                       in: 0...0.1)
            }
        }
    }
}

#Preview {
    LightPanel()
}
