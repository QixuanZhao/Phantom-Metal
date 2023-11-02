//
//  ContentView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/11.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.self) var environment
    @EnvironmentObject private var renderer: Renderer
    @State private var backgroundColor: Color = .black
    @State private var scale: Float = 1.0
    @State private var velocity: Float = 1.0
    @State private var sensitivity: Float = 1.0
    @State private var roll: Float = 0
    
    var body: some View {
        HStack (spacing: 0) {
            VStack (alignment: .center) {
                ColorPicker("Background Color", selection: $backgroundColor)
                Slider(value: $scale, in: -5...5)
                    .frame(width: 150)
                HStack {
                    Text("Scale:")
                    Text(String(format: "% 4.2f", scale)).monospaced()
                }
                Slider(value: $velocity, in: 0.1...10)
                    .frame(width: 150)
                HStack {
                    Text("Camera Velocity:")
                    Text(String(format: "% 4.2f", velocity)).monospaced()
                }
                Slider(value: $sensitivity, in: 0.1...5)
                    .frame(width: 150)
                HStack {
                    Text("Camera Sensitivity:")
                    Text(String(format: "% 4.2f", sensitivity)).monospaced()
                }
                Slider(value: $roll, in: -180...180)
                    .frame(width: 150)
                HStack {
                    Text("Camera Roll:")
                    Text(String(format: "% 7.2f", roll)).monospaced()
                }
                Spacer()
                Text(String(
                    format: "Eular Angles: (% 6.2f, % 7.2f, %7.2f)",
                    renderer.camera.pitch,
                    renderer.camera.yaw,
                    renderer.camera.roll
                )).font(.caption.monospaced())
                Text(String(
                    format: "Front: (% 4.2f, % 4.2f, % 4.2f)",
                    renderer.camera.front.x,
                    renderer.camera.front.y,
                    renderer.camera.front.z
                )).font(.caption.monospaced())
                Text(String(
                    format: "Position: (% 4.2f, % 4.2f, % 4.2f)",
                    renderer.camera.position.x,
                    renderer.camera.position.y,
                    renderer.camera.position.z
                )).font(.caption.monospaced())
                HStack {
                    Text(String(format: "%6.2f FPS", renderer.fps))
                        .font(.caption.monospaced())
                    Text("\(Int(renderer.resolution.width)) x \(Int(renderer.resolution.height))")
                        .font(.caption)
                }
            }
            .padding()
            MetalView()
                .focusable()
                .padding()
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
                    if event.phase == .down {
                        if let char = event.characters.first {
                            renderer.controller.movingDirections.insert(FPSCameraController.Direction.map(char))
                        }
                    } else if event.phase == .up {
                        if let char = event.characters.first {
                            renderer.controller.movingDirections.remove(FPSCameraController.Direction.map(char))
                        }
                    }
                    return .handled
                }
        }
//        .fileImporter(isPresented: $dialogVisible, allowedContentTypes: [.threeDContent], onCompletion: { result in
//            if let path = try? result.get() {
//                print(path)
//            }
//        })
        .onChange(of: backgroundColor) {
            renderer.backgroundColor = backgroundColor.resolve(in: environment)
        }
        .onChange(of: scale) {
            renderer.rgbTriangle.scaling = SIMD3<Float>(scale, scale, scale)
        }
        .onChange(of: velocity) {
            renderer.controller.velocity = velocity
        }
        .onChange(of: sensitivity) {
            renderer.controller.sensitivity = sensitivity
        }
        .onChange(of: roll) {
            renderer.controller.camera?.roll = roll
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(Renderer())
}
