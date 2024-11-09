//
//  LSFSurfaceConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/9/1.
//

import SwiftUI

struct LSFSurfaceConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor = false
    @State private var selectedPointSetName: String?
    @State private var selectedUVSetName: String?
//    @State private var innerKnotCount: Int = 0
    
    @State private var uPattern: [Float] = [0, 1]
    @State private var vPattern: [Float] = [0, 1]
    
    @State private var fillKnots: Bool = true
    @State private var uDegree: Int = 3
    @State private var vDegree: Int = 3
    
    @State private var innerU: Float = 0
    @State private var innerV: Float = 0
    
    private var U: [IndexedTableStringItem] {
        uPattern.enumerated().map { IndexedTableStringItem(id: $0.offset, name: "\($0.element)") }
    }
                                     
    private var V: [IndexedTableStringItem] {
        vPattern.enumerated().map { IndexedTableStringItem(id: $0.offset, name: "\($0.element)") }
    }
    
    private var pointSets: [TableStringItem] {
        drawables.keys.filter { drawables[$0] is PointSet }
            .map { TableStringItem(name: $0) }
    }
    
    func fitLSFSurface() {
        if let selectedPointSetName,
           let selectedUVSetName {
            
            let points = drawables[selectedPointSetName] as! PointSet
            let uvs = drawables[selectedUVSetName] as! PointSet
            
            var samples: [(SIMD2<Float>, SIMD3<Float>)] = []
            for i in 0..<points.points.count {
                let uv = SIMD2<Float>(uvs.points[i].x, uvs.points[i].y)
                let p = points.points[i]
                samples.append((uv, p))
            }
            
            var uKnots = BSplineBasis.averageKnots(for: uPattern, withDegree: uDegree)
            var vKnots = BSplineBasis.averageKnots(for: vPattern, withDegree: vDegree)
            
            if fillKnots {
                uKnots = BSplineBasis.fillKnots(in: uKnots,
                                                count: uPattern.count - 2)
                vKnots = BSplineBasis.fillKnots(in: vKnots,
                                                count: vPattern.count - 2)
            }
            
            let resultSurface = try? BSplineApproximator.approximate(
                samples: samples,
                uBasis: .init(degree: uDegree, knots: uKnots),
                vBasis: .init(degree: vDegree, knots: vKnots)
            )
            
            if let resultSurface {
                resultSurface.name = drawables.uniqueName(name: "LSF Surf")
                drawables.insert(key: resultSurface.name, value: resultSurface)
            }
        }
    }
    
    var panel: some View {
        VStack {
            HStack {
                GroupBox {
                    Table(pointSets, selection: $selectedUVSetName) {
                        TableColumn("Name") { Text($0.name) }
                    }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                } label: {
                    Text("UV Set")
                }
                
                GroupBox {
                    Table(pointSets, selection: $selectedPointSetName) {
                        TableColumn("Name") { Text($0.name) }
                    }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                } label: {
                    Text("Point Set")
                }
            }
            
            HStack {
                GroupBox {
                    HStack {
                        TextField("u", value: $innerU, format: .number)
                        Button {
                            if let index = uPattern.firstIndex(where: { innerU <= $0 }) {
                                if index != 0 && innerU < uPattern[index] {
                                    uPattern.insert(innerU, at: index)
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    Table(U) {
                        TableColumn("#") { item in
                            Text(item.name).monospacedDigit()
                                .contextMenu {
                                    Button {
                                        uPattern.remove(at: item.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                        .pasteDestination(for: String.self,
                            action: { strings in
                            print(strings.count)
                            if let string = strings.first {
                                print(string)
                                if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                                    let parameters = json.map { Float($0) }
                                    uPattern = parameters
                                }
                            }
                        })
                } label: {
                    Text("u pattern")
                }
                
                GroupBox {
                    HStack {
                        TextField("v", value: $innerV, format: .number)
                        Button {
                            if let index = vPattern.firstIndex(where: { innerV <= $0 }) {
                                if index != 0 && innerV < vPattern[index] {
                                    vPattern.insert(innerV, at: index)
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    Table(V) {
                        TableColumn("#") { item in
                            Text(item.name).monospacedDigit()
                                .contextMenu {
                                    Button {
                                        vPattern.remove(at: item.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                        .pasteDestination(for: String.self,
                            action: { strings in
                            print(strings.count)
                            if let string = strings.first {
                                print(string)
                                if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                                    let parameters = json.map { Float($0) }
                                    vPattern = parameters
                                }
                            }
                        })
                } label: {
                    Text("v pattern")
                }
            }.textFieldStyle(.roundedBorder)
            
            HStack {
                Toggle("Max Knots", isOn: $fillKnots)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Spacer()
                Stepper("p & q: \(uDegree)",
                        value: $uDegree, in: 1...6)
                Stepper("\(vDegree)", value: $vDegree, in: 1...6)
            }
            
            Button {
                fitLSFSurface()
            } label: {
                HStack {
                    Spacer()
                    Text("Fit")
                    Spacer()
                }
            }.disabled(selectedPointSetName == nil || selectedUVSetName == nil || selectedPointSetName == selectedUVSetName)
        }.frame(minWidth: 300).padding()
    }
    
    var body: some View {
        Button {
            showConstructor.toggle()
        } label: {
            Label("Guide", systemImage: "tray")
        }.popover(isPresented: $showConstructor) {
            panel
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    drawables.insert(key: "What", value: PointSet(points: [.zero]))
    drawables.insert(key: "Ever", value: PointSet(points: [.zero]))
    drawables.insert(key: "You", value: PointSet(points: [.zero]))
    
    return LSFSurfaceConstructor().padding()
        .environment(drawables)
}
