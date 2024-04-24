//
//  PropertyPanel.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/14.
//

import SwiftUI

struct PropertyPanel: View {
    @Environment(DrawableCollection.self) private var drawables
    let drawableName: String?
    private var drawable: DrawableBase? { drawables[drawableName] }
    
    @State private var document: JSONDocument = .init()
    @State private var showExporter: Bool = false
    @State private var switching: Bool = false
    
    var body: some View {
        VStack {
            if let drawable {
                HStack {
                    Text(drawable.name).font(.caption)
                    Spacer()
                    Button {
                        if let data = JSONObjectParser.dump(drawable: drawable) {
                            document.json = String(decoding: data, as: UTF8.self)
                            showExporter = true
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up").labelStyle(.iconOnly)
                    }.fileExporter(isPresented: $showExporter,
                                   document: document,
                                   contentTypes: [.json]) { result in
                        switch result {
                        case .success(let url):
                            print("save to \(url)")
                        case .failure(let error):
                            print(error.localizedDescription)
                        }
                    }.controlSize(.small).buttonStyle(.plain)
                }
                if !switching {
                    if let curve = drawable as? BSplineCurve {
                        BSplineCurveProperties(curve: curve)
                    } else if let curve = drawable as? BézierCurve {
                        BézierCurveProperties(curve: curve)
                    } else if let surface = drawable as? BSplineSurface {
                        BSplineSurfaceProperties(surface: surface)
                    }
                } else {
                    ContentUnavailableView("Switching", systemImage: "point.bottomleft.forward.to.arrowtriangle.uturn.scurvepath.fill")
                }
            } else {
                Text("No drawable selected").font(.caption).foregroundStyle(Color.secondary)
            }
        }.onChange(of: drawable) {
            switching = true
            // I fixed the weird bug via this weird async code
            DispatchQueue.main.asyncAfter(deadline: .now()) { switching = false }
        }
    }
    
    init(drawableName: String?) {
        self.drawableName = drawableName
    }
}

#Preview {
    PropertyPanel(drawableName: nil)
        .environment(DrawableCollection())
}
