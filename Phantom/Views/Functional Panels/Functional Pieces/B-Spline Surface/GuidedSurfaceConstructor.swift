//
//  GuidedSurfaceConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/5/21.
//

import SwiftUI

struct GuidedSurfaceConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor = false
    
    @State private var selectedCurvesNames: Set<String> = []
    @State private var selectedSurfaceName: String?
    
    @State private var fixedU: [Float] = [0, 1]
    @State private var fixedV: [Float] = [0, 1]
    
    @State private var innerUFixed: Float = 0.5
    @State private var innerVFixed: Float = 0.5
    
    @State private var guideTimes: Int = 5
    
    @State private var exportsError: Bool = true
    @State private var perCurveSampleCount: Int = 50
    @State private var shiftingParameter: Bool = true
    
    @State private var knotDensity: Int = 1
    
    private var curves: [TableStringItem] {
        drawables.keys.filter { drawables[$0] is BSplineCurve }
            .map { TableStringItem(name: $0) }
    }
    
    private var surfaces: [TableStringItem] {
        drawables.keys.filter { drawables[$0] is BSplineSurface }
            .map { TableStringItem(name: $0) }
    }
    
    private var U: [TableStringItem] {
        fixedU.map { TableStringItem(name: "\($0)") }
    }
                                     
    private var V: [TableStringItem] {
        fixedV.map { TableStringItem(name: "\($0)") }
    }
    
    var body: some View {
        Button {
            showConstructor.toggle()
        } label: {
            Label("Guide", systemImage: "moon.dust.fill")
        }.popover(isPresented: $showConstructor) {
            VStack {
                HStack {
                    GroupBox {
                        Table(curves, selection: $selectedCurvesNames) {
                            TableColumn("Name") { Text($0.name) }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                    } label: {
                        Text("Guides")
                    }
                    
                    GroupBox {
                        Table(surfaces, selection: $selectedSurfaceName) {
                            TableColumn("Name") { Text($0.name) }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                    } label: {
                        Text("Base Surface")
                    }
                }
                HStack {
                    GroupBox {
                        HStack {
                            TextField("Inner U Fixed", value: $innerUFixed, format: .number)
                            Button {
                                if let index = fixedU.firstIndex(where: { innerUFixed <= $0 }) {
                                    if index != 0 && innerUFixed < fixedU[index] {
                                        fixedU.insert(innerUFixed, at: index)
                                    }
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                        Table(U) {
                            TableColumn("#") { Text($0.name).monospacedDigit() }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                            .pasteDestination(for: String.self,
                                action: { strings in
                                print(strings.count)
                                if let string = strings.first {
                                    print(string)
                                    if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                                        let parameters = json.map { Float($0) }
                                        fixedU = parameters
                                    }
                                }
                            })
                    } label: {
                        Text("Fixed U")
                    }
                    
                    GroupBox {
                        HStack {
                            TextField("Inner V Fixed", value: $innerVFixed, format: .number)
                            Button {
                                if let index = fixedV.firstIndex(where: { innerVFixed <= $0 }) {
                                    if index != 0 && innerVFixed < fixedV[index] {
                                        fixedV.insert(innerVFixed, at: index)
                                    }
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                        Table(V) {
                            TableColumn("#") { Text($0.name).monospacedDigit() }
                        }.frame(minHeight: 100).tableColumnHeaders(.hidden)
                            .pasteDestination(for: String.self,
                                action: { strings in
                                print(strings.count)
                                if let string = strings.first {
                                    print(string)
                                    if let json = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!) as? [Double] {
                                        let parameters = json.map { Float($0) }
                                        fixedV = parameters
                                    }
                                }
                            })
                    } label: {
                        Text("Fixed V")
                    }
                }.textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                HStack {
                    Toggle("Error", isOn: $exportsError)
                    Spacer()
                    Stepper("PCSC \(perCurveSampleCount)",
                            value: $perCurveSampleCount,
                            in: 10...200,
                            step: 10)
                }
                HStack {
                    Toggle("Shift Parameters", isOn: $shiftingParameter)
                    Spacer()
                }
                Picker("Knot Density", selection: $knotDensity) {
                    Text("x1").tag(1)
                    Text("x2").tag(2)
                    Text("x3").tag(3)
                }
                HStack (spacing: .zero) {
                    Stepper("Times \(guideTimes)", value: $guideTimes, in: 1...1000)
                    Stepper("", value: $guideTimes, in: 1...1000, step: 10).labelsHidden()
                    Stepper("", value: $guideTimes, in: 1...1000, step: 100).labelsHidden()
                    Spacer()
                }
                Button {
                    if !selectedCurvesNames.isEmpty,
                        let selectedSurfaceName {
                        do {
                            var surface = drawables[selectedSurfaceName] as! BSplineSurface
                            let guideCurves = selectedCurvesNames.map { drawables[$0] as! BSplineCurve }
                            
                            for k in 0..<guideTimes {
                                let startValueCandidates = surface.generateStartValueCandidates()
                                
                                let projectionResult = surface.project(guideCurves,
                                                                       perCurveSampleCount: perCurveSampleCount,
                                                                       parameterShift: shiftingParameter ? Float(k) / Float(guideTimes) : 0,
                                                                       startValueCandidates: startValueCandidates)
                                
                                if exportsError {
                                    let error = LineSegments(segments: projectionResult.map { ($0.point, $0.projectedPoint) })
                                    error.name = drawables.uniqueName(name: "E (\(k))")
                                    error.setColorStrategy(.lengthBinary(standard: 0.1))
                                    error.setColor([1, 0, 0, 1], [0, 1, 0, 1])
                                    drawables.insert(key: error.name, value: error)
                                    
                                    let denseSamples = surface.project(guideCurves,
                                                                       perCurveSampleCount: 1000,
                                                                       startValueCandidates: startValueCandidates)
                                    let generalizationError = LineSegments(segments: denseSamples.map { ($0.point, $0.projectedPoint) })
                                    generalizationError.name = drawables.uniqueName(name: "GE (\(k))")
                                    generalizationError.setColorStrategy(.lengthBinary(standard: 0.1))
                                    generalizationError.setColor([1, 0, 0, 1], [0, 1, 0, 1])
                                    drawables.insert(key: generalizationError.name, value: generalizationError)
                                }
                                
                                let guidanceResult = try BSplineApproximator.guide(originalSurface: surface,
                                                                                   samples: projectionResult.map { ($0.parameters, $0.point) },
                                                                                   isoU: fixedU.map { $0 * (surface.uBasis.knots.last!.value - surface.uBasis.knots.first!.value) + surface.uBasis.knots.first!.value },
                                                                                   isoV: fixedV.map { $0 * (surface.vBasis.knots.last!.value - surface.vBasis.knots.first!.value) + surface.vBasis.knots.first!.value },
                                                                                   knotDensityFactor: knotDensity)
                                
                                surface = guidanceResult.modifiedSurface
                                
                                surface.name = drawables.uniqueName(name: "Guided Surface (\(k + 1))")
                                drawables.insert(key: surface.name, value: surface)
                            }
                            
                            if exportsError {
                                let startValueCandidates = surface.generateStartValueCandidates()
                                let projectionResult = surface.project(guideCurves,
                                                                       perCurveSampleCount: perCurveSampleCount,
                                                                       startValueCandidates: startValueCandidates)
                                let error = LineSegments(segments: projectionResult.map { ($0.point, $0.projectedPoint) })
                                error.name = drawables.uniqueName(name: "E (\(guideTimes))")
                                error.setColorStrategy(.lengthBinary(standard: 0.1))
                                error.setColor([1, 0, 0, 1], [0, 1, 0, 1])
                                drawables.insert(key: error.name, value: error)
                                
                                let denseSamples = surface.project(guideCurves,
                                                                   perCurveSampleCount: 1000,
                                                                   startValueCandidates: startValueCandidates)
                                let generalizationError = LineSegments(segments: denseSamples.map { ($0.point, $0.projectedPoint) })
                                generalizationError.name = drawables.uniqueName(name: "GE (\(guideTimes))")
                                generalizationError.setColorStrategy(.lengthBinary(standard: 0.1))
                                generalizationError.setColor([1, 0, 0, 1], [0, 1, 0, 1])
                                drawables.insert(key: generalizationError.name, value: generalizationError)
                            }
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Guide")
                        Spacer()
                    }
                }.buttonStyle(.borderedProminent)
                    .disabled(selectedCurvesNames.isEmpty || selectedSurfaceName == nil)
            }.frame(minWidth: 300).padding()
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    drawables.insert(key: "What", value: BSplineCurve())
    drawables.insert(key: "Ever", value: BSplineCurve())
    drawables.insert(key: "You", value: BSplineCurve())
    
    return GuidedSurfaceConstructor().padding()
        .environment(drawables)
}
