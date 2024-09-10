//
//  CurveSampler.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/9/1.
//

import SwiftUI

struct CurveSampler: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showPanel = false
    @State private var curves: [BSplineCurve] = []
    
    var panel: some View {
        HStack {
            
        }
    }
    
    var body: some View {
        Button {
            showPanel = true
        } label: {
            Label("Curve Sampler", systemImage: "book.pages")
        }.popover(isPresented: $showPanel) {
            panel
        }
    }
}

#Preview {
    CurveSampler()
}
