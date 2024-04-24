//
//  BSplineCurveCombiner.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/3/3.
//

import SwiftUI

struct BSplineCurveCombiner: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showPopover = false
    @State private var newCurveName = "Combined Curve"
    
    @State private var restCurves: [String] = []
    @State private var selectedCurveName: String? = nil
    @State private var selectedPickedCurveName: String? = nil
    @State private var pickedCurves: [String] = []
    
    var rest: [TableStringItem] {
        restCurves.map { TableStringItem(name: $0) }
    }
    
    var picked: [TableStringItem] {
        pickedCurves.map { TableStringItem(name: $0) }
    }
    
    var body: some View {
        Button {
            showPopover = true
        } label: {
            Label("Curve Combiner", systemImage: "link")
        }.popover(isPresented: $showPopover) {
            HStack (alignment: .center) {
                GroupBox("Picked Curves") {
                    Table(rest, selection: $selectedCurveName) {
                        TableColumn("Name") { Text($0.name) }
                    }.tableColumnHeaders(.hidden)
                }.frame(minWidth: 200, minHeight: 300)
                
                VStack {
                    Button {
                        if let selectedCurveName {
                            restCurves.remove(at: restCurves.firstIndex(of: selectedCurveName)!)
                            pickedCurves.append(selectedCurveName)
                        }
                        selectedCurveName = nil
                    } label: {
                        Label("", systemImage: "arrowshape.left.fill")
                    }.disabled(selectedCurveName == nil)
                    
                    Button {
                        if let selectedPickedCurveName {
                            pickedCurves.remove(at: pickedCurves.firstIndex(of: selectedPickedCurveName)!)
                            restCurves.append(selectedPickedCurveName)
                        }
                        selectedPickedCurveName = nil
                    } label: {
                        Label("", systemImage: "arrowshape.right.fill")
                    }.disabled(selectedPickedCurveName == nil)
                }.labelStyle(.iconOnly)
                
                GroupBox("B-Spline Curves") {
                    Table(rest, selection: $selectedCurveName) {
                        TableColumn("Name") { Text($0.name) }
                    }.tableColumnHeaders(.hidden)
                }.frame(minWidth: 200, minHeight: 300)
            }.padding()
        }.onAppear {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedCurves.contains($0)
            }
        }.onChange(of: drawables.count) {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedCurves.contains($0)
            }
        }
    }
}

#Preview {
    BSplineCurveCombiner()
        .environment(DrawableCollection())
        .padding()
}
