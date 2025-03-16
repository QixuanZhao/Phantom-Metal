//
//  PointsToSurfaceProjectorView.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/10/27.
//

import SwiftUI

struct PointsToSurfaceProjectorView: View {
    
    @State private var viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            Stepper("Distance Tolerance (ε1): \(viewModel.distanceTolerance)",
                    value: $viewModel.distanceToleranceMagnitude,
                    in: 0...6).monospacedDigit()
            Slider(value: $viewModel.distanceToleranceMagnitude, in: 0...6, step: 1)
            
            Text("Cosine Tolerance (ε2): \(viewModel.cosineTolerance)").monospacedDigit()
            Slider(value: $viewModel.angleTolerance, in: 0.001...5)
            
            Table(of: TableStringItem.self, selection: $viewModel.selectedPointSetNameList) {
                TableColumn("Name") { item in Text(item.name) }
            } rows: {
                ForEach (viewModel.pointSetNameList) { item in TableRow(item) }
            }.tableColumnHeaders(.hidden)
                .frame(minHeight: 200)
            Text("Selected Point Set Count: \(viewModel.selectedPointSetNameList.count)")
            
            Button {
                viewModel.project()
            } label: {
                HStack {
                    Spacer()
                    Text("Confirm")
                    Spacer()
                }
            }.buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedPointSetNameList.isEmpty)
        }
    }
}

extension PointsToSurfaceProjectorView {
    
    @MainActor
    @Observable
    class ViewModel {
        let drawables: DrawableCollection
        let surface: BSplineSurface
        
        var pointSetNameList: [TableStringItem] {
            drawables.keys.filter {
                drawables[$0] is PointSet
            }.map { TableStringItem(name: $0) }
        }
        
        var distanceToleranceMagnitude: Float = 6
        var angleTolerance: Float = 0.001 // degrees
        var selectedPointSetNameList: Set<String> = []
        
        var distanceTolerance: Float {
            pow(0.1, distanceToleranceMagnitude)
        }
        
        var cosineTolerance: Float {
            cos(Float.pi / 2 - Float(Angle(degrees: Double(angleTolerance)).radians))
        }
        
        func project() {
            let startValueCandidates = surface.generateStartValueCandidates()
            let lineSegments: [(SIMD3<Float>, SIMD3<Float>)]
            = selectedPointSetNameList.map {
                drawables[$0]! as! PointSet
            }.reduce(into: []) { partialResult, pointSet in
                let projectedPoints = surface.inverse(pointSet.points,
                                                      startValueCandidates: startValueCandidates,
                                                      e1: distanceTolerance,
                                                      e2: cosineTolerance,
                                                      maxIteration: 100)
                guard projectedPoints.count == pointSet.points.count else { return }
                partialResult.append(contentsOf: projectedPoints.enumerated().map {
                    (surface.point(at: $0.element)!, pointSet.points[$0.offset])
                })
            }
            
            let lss = LineSegments(segments: lineSegments)
            lss.setColor(.init(1, 0, 0, 1), .init(0, 1, 0, 1))
            lss.setColorStrategy(.lengthBinary(standard: 0.1))
            lss.name = drawables.uniqueName(name: "Projection on \(surface.name)")
            drawables.insert(key: lss.name, value: lss)
        }
        
        init(drawables: DrawableCollection, surface: BSplineSurface) {
            self.drawables = drawables
            self.surface = surface
        }
    }
}

#Preview {
    PointsToSurfaceProjectorView(viewModel: .init(drawables: .init(), surface: .init()))
        .frame(minWidth: 300).padding()
}
