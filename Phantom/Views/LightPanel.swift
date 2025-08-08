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
        VStack {
            ForEach(Array(renderer.lights.enumerated()), id: \.offset) { (offset, light) in
                Grid (alignment: .leadingFirstTextBaseline) {
                    GridRow {
                        Text("Intensity")
                        Slider(value: .init(get: { light.intensity },
                                            set: { renderer.lights[offset].intensity = $0 }),
                               in: 0...5)
                    }
                    
                    GridRow {
                        Text("Ambient")
                        Slider(value: .init(get: { light.ambient },
                                            set: { renderer.lights[offset].ambient = $0 }),
                               in: 0...1)
                    }
                    
                    DisclosureGroup {
                        DirectionPicker(
                            direction: .init(
                                get: { light.direction },
                                set: { renderer.lights[offset].direction = $0 }
                            )
                        )
                        .frame(minHeight: 100)
                    } label: {
                        Text("Direction")
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary)
                }
            }
        }
    }
}

#Preview {
    LightPanel()
        .environment(Renderer())
        .padding()
}
