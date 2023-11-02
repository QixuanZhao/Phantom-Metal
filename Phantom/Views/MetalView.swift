//
//  MetalView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/11.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    @EnvironmentObject private var renderer: Renderer
    
    public func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.focusRingType = .none
        renderer.initMtl(view)
        return view
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
    }
    
    public typealias NSViewType = MTKView
}

#Preview {
    MetalView()
        .environmentObject(Renderer())
}
