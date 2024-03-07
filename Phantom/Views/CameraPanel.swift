//
//  CameraPanel.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/28.
//

import SwiftUI

struct CameraPanel: View {
    @Environment(Renderer.self) private var renderer: Renderer
    
    var body: some View {
        Grid (alignment: .leadingFirstTextBaseline) {
            Picker("Projection Type", selection: .init(get: {
                renderer.uniform.pointSizeAndCurvilinearPerspective[1] == 1
            }, set: {
                renderer.uniform.pointSizeAndCurvilinearPerspective[1] = $0 ? 1 : 0
            })) {
                Text("Rectilinear Perspective").tag(false)
                Text("Curvilinear Perspective").tag(true)
            }
            
            GridRow {
                Text("Velocity")
                Slider(value: .init(get: { renderer.controller.velocity }, set: {
                    renderer.controller.velocity = $0
                }), in: 0.01...1000)
            }
            
            GridRow {
                Text("Sensitivity")
                Slider(value: .init(get: {
                    renderer.controller.sensitivity
                }, set: {
                    renderer.controller.sensitivity = $0
                }), in: 0.001...10)
            }
            
            GridRow {
                Text("FOV")
                Slider(value: .init(get: {
                    renderer.camera.fov
                }, set: {
                    renderer.camera.fov = $0
                }), in: 0...180)
            }
            
            GridRow {
                Text("Near")
                Slider(value: .init(get: { renderer.camera.near }, set: {
                    renderer.camera.near = $0
                }), in: 0.0001...10)
            }
            
            GridRow {
                Text("Far")
                Slider(value: .init(get: { renderer.camera.far }, set: {
                    renderer.camera.far = $0
                }), in: 50...90000)
            }
        }.pickerStyle(.radioGroup).textFieldStyle(.roundedBorder)
    }
}

#Preview {
    CameraPanel()
        .environment(Renderer())
        .padding()
}
