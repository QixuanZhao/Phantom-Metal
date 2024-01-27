//
//  GordonSurfaceConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/26.
//

import SwiftUI

struct TableStringItem: Identifiable {
    var id: String { name }
    var name: String
}

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
    
    var gordonPanel: some View {
        VStack {
            HStack {
                VStack {
                    HStack {
                        GroupBox {
                            Table(uSections, selection: $selectedUCurveName) {
                                TableColumn("Name") { item in
                                    Text(item.name)
                                }
                            }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                        } label: {
                            Text("u Curves")
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
                                TableColumn("Name") { item in
                                    Text(item.name)
                                }
                            }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                        } label: {
                            Text("v Curves")
                        }
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
                                TableColumn("Name") { item in
                                    Text(item.name)
                                }
                            }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                        } label: {
                            Text("Guide Curves")
                        }
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
                        TableColumn("Name") { item in
                            Text(item.name)
                        }
                    }.tableColumnHeaders(.hidden)
                }.frame(minWidth: 200)
            }.controlSize(.small)
            
            Button {
                do {
                    let loft = try Loft(sections: pickedUSections.map { drawables[$0]! as! BSplineCurve })
                    if let surface = loft.surface {
                        surface.name = drawables.uniqueName(name: surface.name)
                        drawables.insert(key: surface.name, value: surface)
                    } else {
                        print("No surface generated")
                    }
                } catch {
                    print(error.localizedDescription)
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Confirm")
                    Spacer()
                }
            }
        }
    }
    
    var body: some View {
        Button {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve &&
                !pickedUSections.contains($0) &&
                !pickedVSections.contains($0) &&
                !pickedGuideCurves.contains($0)
            }
            showConstructor = true
        } label: {
            Label("Loft Surface", systemImage: "rectangle.split.3x3.fill")
        }.popover(isPresented: $showConstructor) {
            gordonPanel.padding()
        }
    }
    
    init() {
        
    }
}

#Preview {
    let dc = DrawableCollection()
    let curve = BSplineCurve()
    dc.insert(key: curve.name, value: curve)
    
    return GordonSurfaceConstructor().padding()
        .environment(dc)
}
