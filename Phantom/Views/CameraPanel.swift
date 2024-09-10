//
//  CameraPanel.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/28.
//

import SwiftUI

struct CameraPanel: View {
    @Environment(Renderer.self) private var renderer: Renderer
    
    @State private var showCameraLoader = false
    @State private var showCameraExporter = false
    @State private var document: JSONDocument = .init()
    
    var body: some View {
        Grid (alignment: .leadingFirstTextBaseline) {
            HStack {
                Button {
                    showCameraLoader = true
                } label: {
                    Label("Load", systemImage: "doc.fill")
                }.fileImporter(isPresented: $showCameraLoader,
                               allowedContentTypes: [.json]) { result in
                    switch result {
                    case .success(let url):
                        if url.startAccessingSecurityScopedResource() {
                            switch url.pathExtension.lowercased() {
                            case "json":
                                if let camera = JSONObjectParser.parse(cameraURL: url) {
                                    renderer.camera.position = camera.position
                                    renderer.camera.pitch = camera.pitch
                                    renderer.camera.yaw = camera.yaw
                                    renderer.camera.roll = camera.roll
                                } else {
                                    print("Unknown scheme")
                                }
                            default:
                                print("File format not supported")
                            }
                            url.stopAccessingSecurityScopedResource()
                        }
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
                
                Button {
                    if let data = JSONObjectParser.dump(camera: renderer.camera) {
                        document.json = String(decoding: data, as: UTF8.self)
                        showCameraExporter = true
                    }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.up")
                }.fileExporter(isPresented: $showCameraExporter,
                               document: document,
                               contentTypes: [.json]) { result in
                    switch result {
                    case .success(let url):
                        print("save to \(url)")
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
                
                
            }.buttonStyle(.plain).labelStyle(.iconOnly)
            
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
                }), in: 0.01...300)
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
