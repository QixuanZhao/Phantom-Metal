//
//  MiscellaneousPanel.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/28.
//

import SwiftUI

struct MiscellaneousPanel: View {
    @Environment(\.self) var environment
    @Environment(Renderer.self) private var renderer: Renderer
    
    @State private var backgroundColor: Color = .black
    
    var body: some View {
        Grid (alignment: .leadingFirstTextBaseline) {
            GridRow {
                Text("Point Size")
                Slider(value: .init(get: { renderer.uniform.pointSizeAndCurvilinearPerspective.x },
                                    set: { renderer.uniform.pointSizeAndCurvilinearPerspective.x = $0 }), 
                       in: 10...50)
            }
            
            GridRow {
                Text("Background")
                ColorPicker("", selection: .init(get: {
                    Color(cgColor: renderer.backgroundColor?.cgColor ?? .black)
                }, set: {
                    renderer.backgroundColor = $0.resolve(in: environment)
                }))
            }
        }
    }
}

#Preview {
    MiscellaneousPanel()
        .environment(Renderer())
}
