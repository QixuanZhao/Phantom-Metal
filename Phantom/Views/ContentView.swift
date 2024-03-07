//
//  ContentView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/11.
//

import SwiftUI
import ModelIO
import MetalKit

struct ContentView: View {
    @Environment(Renderer.self) private var renderer: Renderer
    @Environment(SceneGraph.self) private var scene: SceneGraph
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var tempFOV: Float = 45
    @State private var firstPinch: Bool = true
    @State private var cameraVSF  = SIMD3<Float>(5, 1, 45)
    @State private var lightProperties = SIMD3<Float>(1, 0.001, 100)
    
    @State private var curvilinearPerspective: Bool = false
    
    @State private var selectedDrawableName: String?
    
    @ViewBuilder
    var metalView: some View {
        MetalView()
            .focusable()
            .simultaneousGesture(
                MagnifyGesture(minimumScaleDelta: .zero)
                    .onChanged { value in
                        if firstPinch {
                            tempFOV = cameraVSF[2]
                            firstPinch = false
                        }
                        let magnification = Float(value.magnification)
                        let tempFovInRadians = tempFOV * Float.pi / 360
                        let deltaFOV = 360 * (tempFovInRadians - atan(magnification * tan(tempFovInRadians))) / Float.pi
                        cameraVSF[2] = max(min(tempFOV + deltaFOV, 179.9999), 0.0001)
                    }.onEnded { _ in
                        firstPinch = true
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: .zero, coordinateSpace: .local)
                    .onChanged({ _ in
                        renderer.controller.viewLock = false
                        renderer.controller.motionLock = false
                    })
                    .onEnded({ _ in
                        renderer.controller.viewLock = true
                        renderer.controller.motionLock = true
                    })
            )
            .onKeyPress(phases: [.down, .up]) { event in
                if let char = event.characters.first, let direction = FPSController.Direction(rawValue: char) {
                    if event.phase == .down {
                        renderer.controller.movingDirections.insert(direction)
                    } else if event.phase == .up {
                        renderer.controller.movingDirections.remove(direction)
                    }
                }
                return .handled
            }
    }
    
    @ViewBuilder
    var leftColumn: some View {
        VSplitView {
            ScrollView {
                VStack (alignment: .center) {
                    GroupBox {
                        CameraPanel().font(.caption)
                    } label: { Label("Camera", systemImage: "camera") }
                    
                    GroupBox {
                        LightPanel().font(.caption)
                    } label: { Label("Light", systemImage: "lightbulb") }
                    
                    GroupBox {
                        MiscellaneousPanel().font(.caption)
                    } label: { Label("Misc", systemImage: "gear") }
                    
                    Spacer()
                    HStack {
//                        Text(String(format: "%6.2f FPS", renderer.fps)).monospaced()
                        Text("\(Int(renderer.resolution.width)) x \(Int(renderer.resolution.height))")
                    }.font(.caption)
                }.padding()
            }
            ScrollView {
                SceneNodeView(node: scene.root)
                    .controlSize(.small)
                    .padding()
            }
        }
    }
    
    @ViewBuilder
    var rightColumn: some View {
        TabView {
            VSplitView {
                DrawableTable(selected: $selectedDrawableName)
                    .frame(minHeight: 100)
                
                VStack {
                    PropertyPanel(drawableName: selectedDrawableName)
                        .frame(width: 250)
                    Spacer()
                }
            }.tabItem {
                Label("Model List", systemImage: "leaf")
            }
            
            VStack {
                ScrollView {
                    MaterialList()
                }
                HStack {
                    Text("Display P3 Wavelengths")
                }.font(.caption2)
                HStack {
                    Text("R: 614.9 nm")
                    Text("G: 544.2 nm")
                    Text("B: 464.2 nm")
                }.monospacedDigit().font(.caption)
            }.tabItem {
                Label("Material List", systemImage: "leaf")
            }
        }
    }
    
    var body: some View {
        HStack (spacing: 0) {
            leftColumn.frame(width: 300)
            Divider()
            metalView.padding().frame(minWidth: 300)
            rightColumn.frame(width: 250).padding([.top, .bottom, .trailing])
        }
    }
}

#Preview {
    ContentView()
        .environment(Renderer())
        .environment(SceneGraph())
        .environment(DrawableCollection())
        .environment(MaterialCollection())
}
