//
//  CurveSamplePointSetPanel.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/10/27.
//

import SwiftUI

struct CurveSamplePointSetPanel: View {
    @State private var viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack (alignment: .leading) {
            Table(viewModel.drawables.keys.filter { key in
                viewModel.drawables[key] is BSplineCurve
            }.map { TableStringItem(name: $0) }, selection: $viewModel.selectedCurveNameList) {
                TableColumn("") { item in
                    Text("\(item.id)")
                }
            }.tableColumnHeaders(.hidden)
            
            HStack (spacing: 0) {
                Stepper("Sample Count \(viewModel.sampleCount)",
                        value: $viewModel.sampleCount,
                        in: 1...1000)
                Group {
                    Stepper("", value: $viewModel.sampleCount,
                            in: 1...1000, step: 5)
                    Stepper("", value: $viewModel.sampleCount,
                            in: 1...1000, step: 10)
                    Stepper("", value: $viewModel.sampleCount,
                            in: 1...1000, step: 50)
                    Stepper("", value: $viewModel.sampleCount,
                            in: 1...1000, step: 100)
                }.labelsHidden()
            }
            Picker("Sample Coverage",
                   selection: $viewModel.sampleCoverage) {
                Text("Sample \(viewModel.sampleCount) points per curve").tag(SampleCoverage.perCurve)
                Text("Sample \(viewModel.sampleCount) points for all curves").tag(SampleCoverage.forAllCurves)
            }
            Button {
                viewModel.sample()
            } label: {
                HStack {
                    Spacer()
                    Label("Sample", systemImage: "play.fill")
                    Spacer()
                }
            }.buttonStyle(.borderedProminent)
            HStack {
                TextField("Point Set Name", text: $viewModel.pointSetName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.export()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }.disabled(viewModel.samples.isEmpty)
            Text("Generated Sample Set Cardinal Number: \(viewModel.samples.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

extension CurveSamplePointSetPanel {
    enum SampleCoverage {
        case perCurve, forAllCurves
    }
    
    @Observable
    class ViewModel {
        let drawables: DrawableCollection
        
        var sampleCoverage: SampleCoverage = .perCurve
        var sampleCount: Int = 50
        var selectedCurveNameList: Set<String> = []
        var samples: [SIMD3<Float>] = []
        var pointSetName: String = "Point Set"
        
        init (drawables: DrawableCollection) {
            self.drawables = drawables
        }
        
        func export() {
            guard !samples.isEmpty else { return }
            let pointSet = PointSet(points: samples)
            pointSet.name = drawables.uniqueName(name: pointSetName)
            drawables.insert(key: pointSet.name, value: pointSet)
        }
        
        func sample() {
            guard !selectedCurveNameList.isEmpty else { return }
            guard sampleCount > 0 else { return }
            
            var perCurveSampleCounts: [Int] = switch sampleCoverage {
            case .perCurve:
                    .init(repeating: sampleCount,
                          count: selectedCurveNameList.count)
            case .forAllCurves:
                    .init(repeating: sampleCount / selectedCurveNameList.count,
                          count: selectedCurveNameList.count)
            }
            
            if sampleCoverage == .forAllCurves {
                let currentPerCurveSampleCount = sampleCount / selectedCurveNameList.count
                let currentSampleCountSum = currentPerCurveSampleCount * selectedCurveNameList.count
                let remainder = sampleCount - currentSampleCountSum
                guard remainder < selectedCurveNameList.count else { return }
                for i in 0..<remainder { perCurveSampleCounts[i] += 1 }
            }
            
            let curves = selectedCurveNameList.map { drawables[$0] as! BSplineCurve }
            guard curves.count == perCurveSampleCounts.count else { return }
            
            self.samples = curves.enumerated().reduce(into: []) { partialResult, item in
                let index = item.offset
                let curve = item.element
                let sampleCount = perCurveSampleCounts[index]
                let curveSamples = (1...sampleCount).map { k in
                    let t = Float(k) / Float(sampleCount + 1)
                    return curve.point(at: t)!
                }
                partialResult.append(contentsOf: curveSamples)
            }
        }
    }
}

#Preview {
    let drawables = DrawableCollection()
    drawables.insert(key: "Curve 1", value: BSplineCurve())
    drawables.insert(key: "Curve 2", value: BSplineCurve())
    drawables.insert(key: "Curve 3", value: BSplineCurve())
    drawables.insert(key: "Curve 4", value: BSplineCurve())
    
    return CurveSamplePointSetPanel(viewModel: .init(drawables: drawables))
        .environment(drawables)
        .padding()
}
