//
//  ModelLoader.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/10.
//

import SwiftUI
import ModelIO
import MetalKit

struct ModelLoader: View {
    @Environment(DrawableCollection.self) private var drawables
    @State private var showFileLoader = false
    
    var body: some View {
        Button { showFileLoader = true } label: {
            Label("Load", systemImage: "cube.transparent.fill")
        }.fileImporter(isPresented: $showFileLoader,
                       allowedContentTypes: [.threeDContent, .json],
                       allowsMultipleSelection: true) { result in
            if let urls = try? result.get() {
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        switch url.pathExtension.lowercased() {
                        case "obj":
                            let asset = MDLAsset(url: url,
                                                 vertexDescriptor: Vertex.modelDescriptor,
                                                 bufferAllocator: MTKMeshBufferAllocator(device: MetalSystem.shared.device))
                            if asset.count > 0,
                               let mesh = asset.object(at: 0) as? MDLMesh {
                                do {
                                    let drawable = try Mesh (mesh: mesh)
                                    drawable.name = drawables.uniqueName(name: mesh.name)
                                    drawables.insert(key: drawable.name, value: drawable)
                                } catch { print(error.localizedDescription) }
                            }
                        case "json":
                            if let drawable = JSONObjectParser.parse(url) {
                                drawable.name = drawables.uniqueName(name: url.lastPathComponent.prefix(while: { $0 != "." }).capitalized)
                                drawables.insert(key: drawable.name, value: drawable)
                            } else {
                                print("Unknown scheme")
                            }
                        default:
                            print("File format not supported")
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
        }
    }
}

#Preview {
    ModelLoader()
        .environment(DrawableCollection())
}
