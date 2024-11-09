//
//  IntersectionPointPanel.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/29.
//

import simd
import SwiftUI

struct IntersectionPointPanel: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var busy = false
    @State private var selectedCurveNameList: Set<String> = []
    @State private var toleranceMagnitude: Int = -6
    
    var tolerance: Float {
        pow(10, Float(toleranceMagnitude))
    }
    
    var curveNameList: [TableStringItem] {
        drawables.keys.filter {
            drawables[$0] is BSplineCurve
        }.map { TableStringItem(name: $0) }
    }
    
    var body: some View {
        VStack {
            Text("Selected Curve Count: \(selectedCurveNameList.count)")
            Table(of: TableStringItem.self, selection: $selectedCurveNameList) {
                TableColumn("Name") { item in
                    Text(item.name)
                }
            } rows: {
                ForEach (curveNameList) { item in
                    TableRow(item)
                }
            }.tableColumnHeaders(.hidden)
            .disabled(busy)
            Stepper("Tolerance \(tolerance)", value: $toleranceMagnitude, in: -6 ... -1)
            Button {
                busy = true
                Task {
                    let sortedNameList = selectedCurveNameList.sorted(by: <)
                    var results: [(SIMD3<Float>, SIMD3<Float>)] = []
                    for i in 0 ..< sortedNameList.count - 1 {
                        let curve1 = drawables[sortedNameList[i]] as! BSplineCurve
                        let curve1StartValueCandidates = curve1.generateStartValueCandidates()
                        for j in i + 1 ..< sortedNameList.count {
                            let curve2 = drawables[sortedNameList[j]] as! BSplineCurve
                            let projectionResult = BSplineCurve.nearestParameter(curve1, curve2,
                                                                                 startValueCandidatesA: curve1StartValueCandidates,
                                                                                 e1: tolerance)
                            let p1 = curve1.point(at: projectionResult.0)!
                            let p2 = curve2.point(at: projectionResult.1)!
                            results.append((p1, p2))
                        }
                    }
                    if !results.isEmpty {
                        let lineSegments = LineSegments(segments: results)
                        lineSegments.name = drawables.uniqueName(name: "Intersection")
                        drawables.insert(key: lineSegments.name, value: lineSegments)
                    }
                    busy = false
                }
            } label: {
                HStack {
                    Spacer()
                    if busy {
                        ProgressView().controlSize(.mini)
                    } else { Text("Comfirm") }
                    Spacer()
                }
            }.buttonStyle(.borderedProminent)
            .disabled(selectedCurveNameList.count < 2 || busy)
        }
    }
}

#Preview {
    IntersectionPointPanel()
        .environment(DrawableCollection())
        .padding()
}
