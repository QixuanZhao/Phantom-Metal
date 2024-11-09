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
    
    @State private var restCurves: [String] = []
    
    @State private var selectedUCurveName: String? = nil
    @State private var selectedVCurveName: String? = nil
    @State private var selectedCurveName: String? = nil
    
    @State private var isoV: [Float] = [0, 1]
    @State private var newV: Float = 0
    
    @State private var isoU: [Float] = [0, 1]
    @State private var newU: Float = 0
    
    var uSections: [TableStringItem] {
        pickedUSections.map { TableStringItem(name: $0) }
    }
    
    var vSections: [TableStringItem] {
        pickedVSections.map { TableStringItem(name: $0) }
    }
    
    var rest: [TableStringItem] {
        restCurves.map { TableStringItem(name: $0) }
    }
    
    var vListView: some View {
        GroupBox {
            HStack {
                TextField("Inner V", value: $newV, format: .number)
                Button {
                    if let index = isoV.firstIndex(where: { newV <= $0 }) {
                        if index != 0 && newV < isoV[index] {
                            isoV.insert(newV, at: index)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            Table(isoV.map { TableStringItem(name: "\($0)") }) {
                TableColumn("#") { Text($0.name).monospacedDigit() }
            }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                .pasteDestination(for: String.self,
                    action: { strings in
                    if let string = strings.first {
                        if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                            let parameters = json.map { Float($0) }
                            isoV = parameters
                        }
                    }
                })
        } label: {
            Text("Fixed V")
        }
    }
    
    var uListView: some View {
        GroupBox {
            HStack {
                TextField("Inner U", value: $newU, format: .number)
                Button {
                    if let index = isoU.firstIndex(where: { newU <= $0 }) {
                        if index != 0 && newU < isoU[index] {
                            isoU.insert(newU, at: index)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            Table(isoU.map { TableStringItem(name: "\($0)") }) {
                TableColumn("#") { Text($0.name).monospacedDigit() }
            }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                .pasteDestination(for: String.self,
                    action: { strings in
                    if let string = strings.first {
                        if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                            let parameters = json.map { Float($0) }
                            isoU = parameters
                        }
                    }
                })
        } label: {
            Text("Fixed U")
        }
    }
    
    @ViewBuilder
    var gordonPanel: some View {
        HStack {
            VStack {
                vListView
                uListView
            }.frame(minWidth: 200)
            
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
            
            guard let gordonSurface = try? GordonSurface(uSections: uSections,
                                                         vSections: vSections,
                                                         isoU: isoU,
                                                         isoV: isoV) else {
                print("Gordon Surface Init Failed")
                return
            }
            
            if gordonSurface.construct() == true {
                let surface = gordonSurface.constructionResult!.gordonSurface
                surface.name = drawables.uniqueName(name: "Gordon Surface")
                drawables.insert(key: surface.name, value: surface)
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
                drawables[$0] is BSplineCurve
                && !pickedUSections.contains($0)
                && !pickedVSections.contains($0)
            }
        }.onChange(of: drawables.count) {
            restCurves = drawables.keys.filter {
                drawables[$0] is BSplineCurve
                && !pickedUSections.contains($0)
                && !pickedVSections.contains($0)
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
