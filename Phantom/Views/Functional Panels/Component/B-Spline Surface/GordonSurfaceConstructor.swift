//
//  GordonSurfaceConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/26.
//

import SwiftUI

struct GordonSurfaceConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor: Bool = false
    
    @State private var pickedUSections: [String] = []
    @State private var pickedVSections: [String] = []
    @State private var pickedGuideCurves: [String] = []
    
    @State private var restCurves: [String] = []
    
    @State private var selectedUCurveName: String? = nil
    @State private var selectedVCurveName: String? = nil
    @State private var selectedGuideCurveName: String? = nil
    @State private var selectedCurveName: String? = nil
    
    @State private var generateVSections: Bool = false
    
    @State private var isoPointsParameters: [Float] = []
    @State private var isoPoints: [[SIMD3<Float>]] = []
    
    @State private var gordonSurface: GordonSurface? = nil
    
    var uSections: [TableStringItem] {
        pickedUSections.map { TableStringItem(name: $0) }
    }
    
    var vSections: [TableStringItem] {
        pickedVSections.map { TableStringItem(name: $0) }
    }
    
    var guides: [TableStringItem] {
        pickedGuideCurves.map { TableStringItem(name: $0) }
    }
    
    var rest: [TableStringItem] {
        restCurves.map { TableStringItem(name: $0) }
    }
    
    @ViewBuilder
    var gordonPanel: some View {
        HStack {
            VStack (alignment: .trailing) {
                HStack {
                    GroupBox {
                        Table(uSections, selection: $selectedUCurveName) {
                            TableColumn("Name") { Text($0.name) }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                    } label: {
                        Text("u Sections")
                    }
                    VStack {
                        Button {
                            restCurves.append(selectedUCurveName!)
                            pickedUSections.remove(at: pickedUSections.firstIndex(of: selectedUCurveName!)!)
                            selectedUCurveName = nil
                        } label: {
                            Image(systemName: "arrowshape.right.fill")
                        }.disabled(selectedUCurveName == nil)
                        Button {
                            pickedUSections.append(selectedCurveName!)
                            restCurves.remove(at: restCurves.firstIndex(of: selectedCurveName!)!)
                            selectedCurveName = nil
                        } label: {
                            Image(systemName: "arrowshape.left.fill")
                        }.disabled(selectedCurveName == nil)
                    }
                }
                
                HStack {
                    GroupBox {
                        Table(vSections, selection: $selectedVCurveName) {
                            TableColumn("Name") { Text($0.name) }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                    } label: { Text("v Sections") }
                    VStack {
                        Button {
                            restCurves.append(selectedVCurveName!)
                            pickedVSections.remove(at: pickedVSections.firstIndex(of: selectedVCurveName!)!)
                            selectedVCurveName = nil
                        } label: {
                            Image(systemName: "arrowshape.right.fill")
                        }.disabled(selectedVCurveName == nil)
                        Button {
                            pickedVSections.append(selectedCurveName!)
                            restCurves.remove(at: restCurves.firstIndex(of: selectedCurveName!)!)
                            selectedCurveName = nil
                        } label: {
                            Image(systemName: "arrowshape.left.fill")
                        }.disabled(selectedCurveName == nil)
                    }
                }
                
                HStack {
                    GroupBox {
                        Table(guides, selection: $selectedGuideCurveName) {
                            TableColumn("Name") { Text($0.name) }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                    } label: { Text("Guide Curves") }
                    VStack {
                        Button {
                            restCurves.append(selectedGuideCurveName!)
                            pickedGuideCurves.remove(at: pickedGuideCurves.firstIndex(of: selectedGuideCurveName!)!)
                            selectedGuideCurveName = nil
                        } label: {
                            Image(systemName: "arrowshape.right.fill")
                        }.disabled(selectedGuideCurveName == nil)
                        Button {
                            pickedGuideCurves.append(selectedCurveName!)
                            restCurves.remove(at: restCurves.firstIndex(of: selectedCurveName!)!)
                            selectedCurveName = nil
                        } label: {
                            Image(systemName: "arrowshape.left.fill")
                        }.disabled(selectedCurveName == nil)
                    }
                }
            }.frame(minWidth: 200)
            
            GroupBox("B-Spline Curves") {
                Table(rest, selection: $selectedCurveName) {
                    TableColumn("Name") { Text($0.name) }
                }.tableColumnHeaders(.hidden)
            }.frame(minWidth: 200)
        }.controlSize(.small)
        
        Button {
            let uSections = pickedUSections.map { drawables[$0]! as! BSplineCurve }
            let vSections = pickedVSections.map { drawables[$0]! as! BSplineCurve }
            let guides = pickedGuideCurves.map { drawables[$0]! as! BSplineCurve }
            
            gordonSurface = GordonSurface(originalUSections: uSections,
                                          originalVSections: vSections,
                                          guideCurves: guides)
            
            if gordonSurface!.construct() {
                gordonSurface!.guide(times: 5)
            }
            
            let surface = gordonSurface!.constructionResult!.gordonSurface
            surface.name = drawables.uniqueName(name: "Gordon Surface")
            drawables.insert(key: surface.name, value: surface)
            
            for (i, s) in gordonSurface!.guideResult.surfaces.enumerated() {
                s.name = drawables.uniqueName(name: "Guided Surface (\(i + 1)")
                drawables.insert(key: s.name, value: s)
            }
            
            for (i, p) in gordonSurface!.guideResult.projectionResult.enumerated() {
                let ls = LineSegments(segments: p.map { ($0.projectedPoint, $0.point) })
                ls.name = drawables.uniqueName(name: "Projection (\(i)")
                drawables.insert(key: ls.name, value: ls)
            }
        } label: {
            HStack {
                Spacer()
                Text("Confirm")
                Spacer()
            }
        }
    }
    
    var body: some View {
        Button {
            showConstructor = true
        } label: {
            Label("Gordon Surface (\(restCurves.count))", systemImage: "rectangle.split.3x3")
        }.popover(isPresented: $showConstructor) {
            VStack {
                gordonPanel
            }.padding()
        }.onAppear {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedUSections.contains($0) &&
                !pickedVSections.contains($0) &&
                !pickedGuideCurves.contains($0)
            }
        }.onChange(of: drawables.count) {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedUSections.contains($0) &&
                !pickedVSections.contains($0) &&
                !pickedGuideCurves.contains($0)
            }
        }
    }
}

#Preview {
    let dc = DrawableCollection()
    let curve = BSplineCurve()
    dc.insert(key: curve.name, value: curve)
    
    return GordonSurfaceConstructor().padding()
        .environment(dc)
}
