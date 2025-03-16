//
//  MetalView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/11.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    @Environment(Renderer.self) private var renderer: Renderer
    @Environment(SceneGraph.self) private var scene: SceneGraph
    
    public func makeNSView(context: Context) -> MTKView {
        renderer.scene = scene
        
        let view = MTKView()
        view.layer?.wantsExtendedDynamicRangeContent = true
        view.focusRingType = .none
        view.device = MetalSystem.shared.device
        view.delegate = renderer
        view.colorPixelFormat = .rgba16Float
        view.colorspace = .init(name: CGColorSpace.displayP3)
        return view
    }
    
    public func updateNSView(_ view: MTKView, context: Context) { }
    
    public typealias NSViewType = MTKView
}

#Preview {
    MetalView()
        .environment(Renderer())
        .environment(SceneGraph())
}
