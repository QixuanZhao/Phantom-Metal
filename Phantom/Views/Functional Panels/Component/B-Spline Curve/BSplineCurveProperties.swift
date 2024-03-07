//
//  BSplineCurveProperties.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/14.
//

import SwiftUI

struct BSplineCurveProperties: View {
    var curve: BSplineCurve
    
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showControlPoints: Bool = true
    @State private var newKnot: Float = 0.5
    @State private var newLowerbound: Float = 0
    @State private var newUpperbound: Float = 1
    
    @State private var showChart: Bool = false
    @State private var showProjector: Bool = false
    
    @State private var distanceToleranceMagnitude: Float = 1
    @State private var angleTolerance: Float = 1 // degrees
    @State private var selectedCurveNameList: Set<String> = []
    
    @State private var matchEnd = false
    
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
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    showProjector = true
                } label: {
                    Text("Project Curve")
                }.popover(isPresented: $showProjector) {
                    VStack {
                        Stepper("Distance Tolerance (ε1): \(distanceTolerance)",
                                value: $distanceToleranceMagnitude,
                                in: 0...6).monospacedDigit()
                        Slider(value: $distanceToleranceMagnitude, in: 0...6, step: 1)
                        
                        Text("Cosine Tolerance (ε2): \(cosineTolerance)").monospacedDigit()
                        Slider(value: $angleTolerance, in: 0.001...5)
                        
                        Table(of: TableStringItem.self, selection: $selectedCurveNameList) {
                            TableColumn("Name") { item in Text(item.name) }
                        } rows: {
                            ForEach (curveNameList) { item in TableRow(item) }
                        }.tableColumnHeaders(.hidden)
                            .frame(minHeight: 200)
                        HStack {
                            Text("Selected Curve Count: \(selectedCurveNameList.count)")
                            Spacer()
                            Toggle(isOn: $matchEnd) {
                                Text("Match End")
                            }
                        }
                        
                        Button {
                            var lineSegments: [(SIMD3<Float>, SIMD3<Float>)] = []
                            let startValueCandidates = curve.generateStartValueCandidates()
                            selectedCurveNameList.map { drawables[$0]! as! BSplineCurve }.forEach { selectedCurve in
                                let domainMin = selectedCurve.basis.knots.first!.value
                                let domainMax = selectedCurve.basis.knots.last!.value
                                let projectionResult = BSplineCurve.nearestParameter(curve, selectedCurve,
                                                                                     startValueCandidatesA: startValueCandidates,
                                                                                     startValueCandidatesB: matchEnd ? [(domainMin, selectedCurve.point(at: domainMin)!),
                                                                                                                        (domainMax, selectedCurve.point(at: domainMax)!)] : [],
                                                                                     e1: distanceTolerance,
                                                                                     e2: cosineTolerance)
                                lineSegments.append((curve.point(at: projectionResult.0)!, selectedCurve.point(at: projectionResult.1)!))
                            }
                            
                            let lss = LineSegments(segments: lineSegments)
                            lss.name = drawables.uniqueName(name: "Nearest Point on \(curve.name)")
                            drawables.insert(key: lss.name, value: lss)
                        } label: {
                            HStack {
                                Spacer()
                                Text("Confirm")
                                Spacer()
                            }
                        }.buttonStyle(.borderedProminent)
                            .disabled(selectedCurveNameList.isEmpty)
                    }.frame(minWidth: 300).padding()
                }
                
                Button {
                    showChart = true
                } label: {
                    Label("Basis", systemImage: "chart.line.uptrend.xyaxis.circle.fill")
                }.popover(isPresented: $showChart) {
                    VStack {
                        HStack {
                            TextField("Knot", value: $newKnot, format: .number)
                            Button {
                                curve.insert(knotValue: newKnot)
                            } label: {
                                Text("insert")
                            }.disabled(curve.basis.knots.first!.value >= newKnot || newKnot >= curve.basis.knots.last!.value)
                            Button {
                                guard let curves = curve.split(at: newKnot) else { return }
                                let curve0 = curves.0
                                let curve1 = curves.1
                                
                                curve0.name = drawables.uniqueName(name: curve0.name)
                                drawables.insert(key: curve0.name, value: curve0)
                                
                                curve1.name = drawables.uniqueName(name: curve1.name)
                                drawables.insert(key: curve1.name, value: curve1)
                            } label: {
                                Text("split")
                            }.disabled(curve.basis.knots.first!.value >= newKnot || newKnot >= curve.basis.knots.last!.value)
                        }.controlSize(.small)
                        
                        HStack {
                            TextField("Lowerbound", value: $newLowerbound, format: .number)
                            Button {
                                if let newCurve = curve.reparameterized(into: newLowerbound ... newUpperbound) {
                                    newCurve.name = drawables.uniqueName(name: "Reparameterized \(curve.name)")
                                    drawables.insert(key: newCurve.name, value: newCurve)
                                }
                            } label: { Text("reparameterize") }
                                .disabled(newLowerbound >= newUpperbound)
                            TextField("Upperbound", value: $newUpperbound, format: .number)
                        }
                        
                        BSplineBasisChart(basis: curve.basis).frame(minWidth: 400, minHeight: 300).controlSize(.mini)
                    }.onChange(of: curve.basis.requireUpdateBasis) {
                        print("property panel update basis: \(curve.basis.requireUpdateBasis)")
                        if curve.basis.requireUpdateBasis {
                            curve.basis.updateTexture()
                        }
                    }.padding().textFieldStyle(.roundedBorder)
                }
            }
            
            GroupBox {
                BSplineCurveControlPointList(curve: curve).frame(minHeight: 200)
                    .controlSize(.small)
            } label: {
                HStack {
                    Text("Control Points")
                    Toggle(isOn: .init(get: { curve.showControlPoints },
                                       set: { value in curve.showControlPoints = value })) {
                        Label("Show", systemImage: curve.showControlPoints ? "eye.fill" : "eye.slash.fill")
                    }.toggleStyle(.button).labelStyle(.iconOnly).buttonStyle(.plain)
                }
            }
        }
    }
    
    init(curve: BSplineCurve) {
        self.curve = curve
    }
}

#Preview {
    BSplineCurveProperties(curve: BSplineCurve())
        .padding()
        .environment(DrawableCollection())
}
