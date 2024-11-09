//
//  CurvesToSurfaceProjectorView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/10/27.
//

import SwiftUI

struct CurvesToSurfaceProjectorView: View {
    
    @State private var viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            Stepper("Per Curve Sample Count \(viewModel.perCurveSampleCountInteger)",
                    value: $viewModel.perCurveSampleCount,
                    in: 10...1000).monospacedDigit()
            Slider(value: $viewModel.perCurveSampleCount, in: 10...900, step: 10)
            
            Stepper("Distance Tolerance (ε1): \(viewModel.distanceTolerance)",
                    value: $viewModel.distanceToleranceMagnitude,
                    in: 0...6).monospacedDigit()
            Slider(value: $viewModel.distanceToleranceMagnitude, in: 0...6, step: 1)
            
            Text("Cosine Tolerance (ε2): \(viewModel.cosineTolerance)").monospacedDigit()
            Slider(value: $viewModel.angleTolerance, in: 0.001...5)
            
            Table(of: TableStringItem.self, selection: $viewModel.selectedCurveNameList) {
                TableColumn("Name") { item in Text(item.name) }
            } rows: {
                ForEach (viewModel.curveNameList) { item in TableRow(item) }
            }.tableColumnHeaders(.hidden)
                .frame(minHeight: 200)
            Text("Selected Curve Count: \(viewModel.selectedCurveNameList.count)")
            
            Button {
                viewModel.project()
            } label: {
                HStack {
                    Spacer()
                    Text("Confirm")
                    Spacer()
                }
            }.buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedCurveNameList.isEmpty)
        }
    }
}

extension CurvesToSurfaceProjectorView {
    @Observable
    class ViewModel {
        let drawables: DrawableCollection
        let surface: BSplineSurface
        
        var perCurveSampleCount: Float = 300
        var perCurveSampleCountInteger: Int { Int(perCurveSampleCount) }
        
        var distanceToleranceMagnitude: Float = 6
        var angleTolerance: Float = 0.001 // degrees
        var selectedCurveNameList: Set<String> = []
        
        var curveNameList: [TableStringItem] {
            drawables.keys.filter {
                drawables[$0] is BSplineCurve
            }.map { TableStringItem(name: $0) }
        }
        
        var distanceTolerance: Float {
            pow(0.1, distanceToleranceMagnitude)
        }
        
        var cosineTolerance: Float {
            cos(Float.pi / 2 - Float(Angle(degrees: Double(angleTolerance)).radians))
        }
        
        func project() {
            var lineSegments: [(SIMD3<Float>, SIMD3<Float>)] = []
            selectedCurveNameList.map { drawables[$0]! as! BSplineCurve }.forEach { curve in
                let projectionResults = surface.project(curve,
                                                        sampleCount: perCurveSampleCountInteger,
                                                        e1: distanceTolerance,
                                                        e2: cosineTolerance,
                                                        maxIteration: 100)
                lineSegments.append(contentsOf: projectionResults.map { ($0.point, $0.projectedPoint) })
            }
            
            let lss = LineSegments(segments: lineSegments)
            lss.setColor(.init(1, 0, 0, 1), .init(0, 1, 0, 1))
            lss.setColorStrategy(.lengthBinary(standard: 0.1))
            lss.name = drawables.uniqueName(name: "Projection on \(surface.name)")
            drawables.insert(key: lss.name, value: lss)
        }
        
        init(drawables: DrawableCollection,
             surface: BSplineSurface) {
            self.drawables = drawables
            self.surface = surface
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    
    return CurvesToSurfaceProjectorView(viewModel: .init(drawables: drawables,
                                                 surface: .init()))
        .frame(minWidth: 300).padding()
}
