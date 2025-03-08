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
    
    @State private var guideTimes: Int = 1
    
    @State private var exportsError: Bool = false
    @State private var perCurveSampleCount: Int = 50
    
    @State private var errorControl: Bool = true
    @State private var targetTolerance: Float = 0.0001
    
    enum ErrorControlType: String {
        case type1, type1RefinedBatched, type1RefinedSingle, type1Refined, ourMethod
    }
    
    @State private var errorControlType: ErrorControlType = .ourMethod
    
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
    
    func performGuidanceWithErrorControlType1RefinedSingle() {
        guard !selectedCurvesNames.isEmpty,
              let selectedSurfaceName else {
            print("Please select at least a curve and a surface")
            return
        }
        
        let surface = drawables[selectedSurfaceName] as! BSplineSurface
        let guideCurves = selectedCurvesNames.map { drawables[$0] as! BSplineCurve }
        
        
        let startValueCandidates = surface.generateStartValueCandidates()
        
        let projectionResult = surface.project(guideCurves,
                                               perCurveSampleCount: perCurveSampleCount,
                                               startValueCandidates: startValueCandidates)
        
        let result = BSplineApproximator.guideWithErrorControlType1RefinedSingle(
            originalSurface: surface,
            samples: projectionResult.map { ($0.parameters, $0.point) },
            isoU: fixedU.map { $0 * (surface.uBasis.knots.last!.value - surface.uBasis.knots.first!.value) + surface.uBasis.knots.first!.value },
            isoV: fixedV.map { $0 * (surface.vBasis.knots.last!.value - surface.vBasis.knots.first!.value) + surface.vBasis.knots.first!.value },
            tolerance: targetTolerance)
        switch result {
        case .failure(let error):
            print(error.localizedDescription)
        case .success(let gr):
            gr.modifiedSurface.name = drawables.uniqueName(name: "Guided Surface T1 RS")
            drawables.insert(key: gr.modifiedSurface.name, value: gr.modifiedSurface)
        }
    }
    
    func performGuidanceWithErrorControlType1RefinedBatched () {
        guard !selectedCurvesNames.isEmpty,
              let selectedSurfaceName else {
            print("Please select at least a curve and a surface")
            return
        }
        
        let surface = drawables[selectedSurfaceName] as! BSplineSurface
        let guideCurves = selectedCurvesNames.map { drawables[$0] as! BSplineCurve }
        
        
        let startValueCandidates = surface.generateStartValueCandidates()
        
        let projectionResult = surface.project(guideCurves,
                                               perCurveSampleCount: perCurveSampleCount,
                                               startValueCandidates: startValueCandidates)
        
        let result = BSplineApproximator.guideWithErrorControlType1RefinedBatch(
            originalSurface: surface,
            samples: projectionResult.map { ($0.parameters, $0.point) },
            isoU: fixedU.map { $0 * (surface.uBasis.knots.last!.value - surface.uBasis.knots.first!.value) + surface.uBasis.knots.first!.value },
            isoV: fixedV.map { $0 * (surface.vBasis.knots.last!.value - surface.vBasis.knots.first!.value) + surface.vBasis.knots.first!.value },
            tolerance: targetTolerance)
        switch result {
        case .failure(let error):
            print(error.localizedDescription)
        case .success(let gr):
            gr.modifiedSurface.name = drawables.uniqueName(name: "Guided Surface T1 RB")
            drawables.insert(key: gr.modifiedSurface.name, value: gr.modifiedSurface)
        }
    }
    
    func performGuidanceWithErrorControlType1Refined () {
        guard !selectedCurvesNames.isEmpty,
              let selectedSurfaceName else {
            print("Please select at least a curve and a surface")
            return
        }
        
        let surface = drawables[selectedSurfaceName] as! BSplineSurface
        let guideCurves = selectedCurvesNames.map { drawables[$0] as! BSplineCurve }
        
        
        let startValueCandidates = surface.generateStartValueCandidates()
        
        let projectionResult = surface.project(guideCurves,
                                               perCurveSampleCount: perCurveSampleCount,
                                               startValueCandidates: startValueCandidates)
        
        let result = BSplineApproximator.guideWithErrorControlType1RefinedMax(
            originalSurface: surface,
            samples: projectionResult.map { ($0.parameters, $0.point) },
            isoU: fixedU.map { $0 * (surface.uBasis.knots.last!.value - surface.uBasis.knots.first!.value) + surface.uBasis.knots.first!.value },
            isoV: fixedV.map { $0 * (surface.vBasis.knots.last!.value - surface.vBasis.knots.first!.value) + surface.vBasis.knots.first!.value },
            tolerance: targetTolerance)
        switch result {
        case .failure(let error):
            print(error.localizedDescription)
        case .success(let gr):
            gr.modifiedSurface.name = drawables.uniqueName(name: "Guided Surface T1 R")
            drawables.insert(key: gr.modifiedSurface.name, value: gr.modifiedSurface)
        }
    }
    
    func performGuidanceWithOurErrorControl () {
        guard !selectedCurvesNames.isEmpty,
              let selectedSurfaceName else {
            print("Please select at least a curve and a surface")
            return
        }
        
        let surface = drawables[selectedSurfaceName] as! BSplineSurface
        let guideCurves = selectedCurvesNames.map { drawables[$0] as! BSplineCurve }
        
        
        let startValueCandidates = surface.generateStartValueCandidates()
        
        let projectionResult = surface.project(guideCurves,
                                               perCurveSampleCount: perCurveSampleCount,
                                               startValueCandidates: startValueCandidates)
        
        let result = BSplineApproximator.guideWithOurErrorControl(
            originalSurface: surface,
            samples: projectionResult.map { ($0.parameters, $0.point) },
            isoU: fixedU.map { $0 * (surface.uBasis.knots.last!.value - surface.uBasis.knots.first!.value) + surface.uBasis.knots.first!.value },
            isoV: fixedV.map { $0 * (surface.vBasis.knots.last!.value - surface.vBasis.knots.first!.value) + surface.vBasis.knots.first!.value },
            tolerance: targetTolerance)
        switch result {
        case .failure(let error):
            print(error.localizedDescription)
        case .success(let gr):
            gr.modifiedSurface.name = drawables.uniqueName(name: "Guided Surface T1")
            drawables.insert(key: gr.modifiedSurface.name, value: gr.modifiedSurface)
        }
    }
    
    func performGuidanceWithErrorControlType1() {
        guard !selectedCurvesNames.isEmpty,
              let selectedSurfaceName else {
            print("Please select at least a curve and a surface")
            return
        }
        
        let surface = drawables[selectedSurfaceName] as! BSplineSurface
        let guideCurves = selectedCurvesNames.map { drawables[$0] as! BSplineCurve }
        
        
        let startValueCandidates = surface.generateStartValueCandidates()
        
        let projectionResult = surface.project(guideCurves,
                                               perCurveSampleCount: perCurveSampleCount,
                                               startValueCandidates: startValueCandidates)
        
        let result = BSplineApproximator.guideWithErrorControlType1EvenBatch(
            originalSurface: surface,
            samples: projectionResult.map { ($0.parameters, $0.point) },
            isoU: fixedU.map { $0 * (surface.uBasis.knots.last!.value - surface.uBasis.knots.first!.value) + surface.uBasis.knots.first!.value },
            isoV: fixedV.map { $0 * (surface.vBasis.knots.last!.value - surface.vBasis.knots.first!.value) + surface.vBasis.knots.first!.value },
            tolerance: targetTolerance)
        switch result {
        case .failure(let error):
            print(error.localizedDescription)
        case .success(let gr):
            gr.modifiedSurface.name = drawables.uniqueName(name: "Guided Surface T1")
            drawables.insert(key: gr.modifiedSurface.name, value: gr.modifiedSurface)
        }
    }
    
    func performGuidance() {
        if !selectedCurvesNames.isEmpty,
            let selectedSurfaceName {
            do {
                var surface = drawables[selectedSurfaceName] as! BSplineSurface
                let guideCurves = selectedCurvesNames.map { drawables[$0] as! BSplineCurve }
                
                for k in 0..<guideTimes {
                    let startValueCandidates = surface.generateStartValueCandidates()
                    
                    let projectionResult = surface.project(guideCurves,
                                                           perCurveSampleCount: perCurveSampleCount,
                                                           parameterShift: 0,
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
                                                                       isoV: fixedV.map { $0 * (surface.vBasis.knots.last!.value - surface.vBasis.knots.first!.value) + surface.vBasis.knots.first!.value })
                    
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
                
                GroupBox {
                    VStack (alignment: .leading) {
                        if errorControl {
                            HStack {
                                Text("Target Error")
                                TextField("Target Error",
                                          value: $targetTolerance,
                                          format: .number)
                                .textFieldStyle(.roundedBorder)
                            }
                            
                            Picker("Error Control Method", selection: $errorControlType) {
                                Text("Type 1").tag(ErrorControlType.type1)
                                Text("Type 1 Refined (Batch)").tag(ErrorControlType.type1RefinedBatched)
                                Text("Type 1 Refined (Single)").tag(ErrorControlType.type1RefinedSingle)
                                Text("Type 1 Refined (Max Only)").tag(ErrorControlType.type1Refined)
                                Text("Our Method").tag(ErrorControlType.ourMethod)
                            }
                        } else {
                            Toggle("Export Error", isOn: $exportsError)
                            
                            HStack (spacing: .zero) {
                                Stepper("Times \(guideTimes)", value: $guideTimes, in: 1...1000)
                                Stepper("", value: $guideTimes, in: 1...1000, step: 10).labelsHidden()
                                Stepper("", value: $guideTimes, in: 1...1000, step: 100).labelsHidden()
                                Spacer()
                            }
                        }
                        
                        Stepper("Per Curve Sample Count: \(perCurveSampleCount)",
                                value: $perCurveSampleCount,
                                in: 10...200,
                                step: 10)
                    }
                } label: {
                    HStack {
                        Text("Error")
                        Spacer()
                        Toggle("Controlled", isOn: $errorControl)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                }
                
                Button {
                    if errorControl {
                        switch errorControlType {
                        case .type1:
                            performGuidanceWithErrorControlType1()
                        case .type1RefinedBatched:
                            performGuidanceWithErrorControlType1RefinedBatched()
                        case .type1RefinedSingle:
                            performGuidanceWithErrorControlType1RefinedSingle()
                        case .type1Refined:
                            performGuidanceWithErrorControlType1Refined()
                        case .ourMethod:
                            performGuidanceWithOurErrorControl()
                        }
                    } else {
                        performGuidance()
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
