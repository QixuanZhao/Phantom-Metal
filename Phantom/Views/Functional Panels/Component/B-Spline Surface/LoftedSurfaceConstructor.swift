//
//  LoftedSurfaceConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/26.
//

import SwiftUI

struct LoftedSurfaceConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor: Bool = false
    
    @State private var pickedSections: [String] = []
    @State private var pickedGuides: [String] = []
    @State private var restCurves: [String] = []
    
    @State private var selectedSectionName: String? = nil
    @State private var selectedGuideName: String? = nil
    @State private var selectedCurveName: String? = nil
    
    var sections: [TableStringItem] {
        pickedSections.map { TableStringItem(name: $0) }
    }
    
    var guides: [TableStringItem] {
        pickedGuides.map { TableStringItem(name: $0) }
    }
    
    var rest: [TableStringItem] {
        restCurves.map { TableStringItem(name: $0) }
    }
    
    @State private var degree: Int = 3
    private var actualDegree: Int {
        min(pickedSections.count - 1, degree)
    }
    
    @State private var blendParameter: BSplineInterpolator.BasisParameter = .u
    
    var body: some View {
        Button {
            showConstructor = true
        } label: {
            Label("Loft Surface (\(restCurves.count))", systemImage: "rectangle.split.3x1")
        }.popover(isPresented: $showConstructor) {
            VStack {
                HStack {
                    VStack {
                        HStack {
                            GroupBox {
                                Table(sections, selection: $selectedSectionName) {
                                    TableColumn("Name") { Text($0.name) }
                                }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                            } label: {
                                HStack {
                                    Text("Sections")
                                    Spacer()
                                    Text("Mind the Order").foregroundStyle(.mint)
                                }
                            }.frame(minWidth: 200)
                            
                            VStack {
                                Button {
                                    restCurves.append(selectedSectionName!)
                                    pickedSections.remove(at: pickedSections.firstIndex(of: selectedSectionName!)!)
                                    selectedSectionName = nil
                                } label: {
                                    Image(systemName: "arrowshape.right.fill")
                                }.disabled(selectedSectionName == nil)
                                Button {
                                    pickedSections.append(selectedCurveName!)
                                    restCurves.remove(at: restCurves.firstIndex(of: selectedCurveName!)!)
                                    selectedCurveName = nil
                                } label: {
                                    Image(systemName: "arrowshape.left.fill")
                                }.disabled(selectedCurveName == nil)
                            }.controlSize(.small)
                        }
                        
                        HStack {
                            GroupBox {
                                Table(guides, selection: $selectedGuideName) {
                                    TableColumn("Name") { Text($0.name) }
                                }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                            } label: {
                                Text("Guides")
                            }.frame(minWidth: 200)
                            
                            VStack {
                                Button {
                                    restCurves.append(selectedGuideName!)
                                    pickedGuides.remove(at: pickedGuides.firstIndex(of: selectedGuideName!)!)
                                    selectedGuideName = nil
                                } label: {
                                    Image(systemName: "arrowshape.right.fill")
                                }.disabled(selectedGuideName == nil)
                                Button {
                                    pickedGuides.append(selectedCurveName!)
                                    restCurves.remove(at: restCurves.firstIndex(of: selectedCurveName!)!)
                                    selectedCurveName = nil
                                } label: {
                                    Image(systemName: "arrowshape.left.fill")
                                }.disabled(selectedCurveName == nil)
                            }.controlSize(.small)
                        }
                    }
                    
                    GroupBox {
                        Table(rest, selection: $selectedCurveName) {
                            TableColumn("Name") { Text($0.name) }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                    } label: { Text("Curves") }.frame(minWidth: 200)
                }
                
                HStack {
                    Text("Maximum Degree: \(pickedSections.count - 1)")
                    Spacer()
                    Stepper("Ideal Degree \(degree)", value: $degree, in: 1...16)
                }
                
                HStack {
                    Picker("Blend Parameter", selection: $blendParameter) {
                        Text("U").tag(BSplineInterpolator.BasisParameter.u)
                        Text("V").tag(BSplineInterpolator.BasisParameter.v)
                    }.pickerStyle(.inline)
                    Spacer()
                    Button {
                        do {
                            let loftResult = try BSplineInterpolator.loft(sections: pickedSections.map { drawables[$0]! as! BSplineCurve },
                                                                          blendParameter: blendParameter,
                                                                          idealDegree: actualDegree)
                            
                            var surface = loftResult.surface
                            
                            surface.name = drawables.uniqueName(name: "Lofted Surface")
                            drawables.insert(key: surface.name, value: surface)
                            
                            let guideCurves = pickedGuides.map { drawables[$0]! as! BSplineCurve }
                            for k in 0..<5 {
                                let projectionResult = surface.project(guideCurves)
                                
                                let guidanceResult = try BSplineApproximator.guide(originalSurface: surface,
                                                                                   samples: projectionResult.map { ($0.parameters, $0.point) },
                                                                                   isoU: blendParameter == .v ? [surface.uBasis.knots.first!.value, surface.uBasis.knots.last!.value] : loftResult.blendParameters,
                                                                                   isoV: blendParameter == .v ? loftResult.blendParameters : [surface.vBasis.knots.first!.value, surface.vBasis.knots.last!.value])
                                
                                surface = guidanceResult.modifiedSurface
                                
                                surface.name = drawables.uniqueName(name: "Guided Surface (\(k))")
                                drawables.insert(key: surface.name, value: surface)
                            }
                        } catch { print(error.localizedDescription) }
                    } label: {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Loft with Degree \(actualDegree)")
                                Spacer()
                            }
                            Spacer()
                        }
                    }.disabled(actualDegree < 1)
                }
                
            }.padding()
        }.onAppear {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedSections.contains($0) &&
                !pickedGuides.contains($0)
            }
        }.onChange(of: drawables.count) {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedSections.contains($0) &&
                !pickedGuides.contains($0)
            }
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    drawables.insert(key: "curve", value: BSplineCurve())
    
    return LoftedSurfaceConstructor()
        .environment(drawables)
        .padding()
}
