//
//  BSplineSurfaceProperties.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/18.
//

import SwiftUI

struct BSplineSurfaceProperties: View {
    @Environment(DrawableCollection.self) private var drawables
    
    var surface: BSplineSurface
    
    let tessellationFactor: Binding<Float>
    @State private var newUKnot: Float = 0.5
    @State private var newVKnot: Float = 0.5
    
    @State private var showChart = false
    @State private var showProjector = false
    
    @State private var perCurveSampleCount: Float = 100
    @State private var distanceToleranceMagnitude: Float = 1
    @State private var angleTolerance: Float = 1 // degrees
    @State private var selectedCurveNameList: Set<String> = []
    
    @State private var isoU: Float = 0
    @State private var isoV: Float = 0
    
    @State private var isocurveU: BSplineCurve? = nil
    @State private var isocurveV: BSplineCurve? = nil
    
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
                    Text("Project/Inverse Curve(s)")
                }.popover(isPresented: $showProjector) {
                    VStack {
                        Stepper("Per Curve Sample Count \(Int(perCurveSampleCount))",
                                value: $perCurveSampleCount,
                                in: 10...1000).monospacedDigit()
                        Slider(value: $perCurveSampleCount, in: 10...900, step: 10)
                        
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
                        Text("Selected Curve Count: \(selectedCurveNameList.count)")
                        
                        Button {
                            var lineSegments: [(SIMD3<Float>, SIMD3<Float>)] = []
                            selectedCurveNameList.map { drawables[$0]! as! BSplineCurve }.forEach { curve in
                                let projectionResults = surface.project(curve,
                                                                        sampleCount: Int(perCurveSampleCount),
                                                                        e1: distanceTolerance,
                                                                        e2: cosineTolerance,
                                                                        maxIteration: 100)
                                lineSegments.append(contentsOf: projectionResults.map { ($0.point, $0.projectedPoint) })
                            }
                            
                            let lss = LineSegments(segments: lineSegments)
                            lss.name = drawables.uniqueName(name: "Projection on \(surface.name)")
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
                
                Button { showChart = true } label: {
                    Label("Basis", systemImage: "chart.line.uptrend.xyaxis.circle.fill")
                }.popover(isPresented: $showChart) {
                    HStack {
                        GroupBox ("U Basis") {
                            VStack {
                                HStack {
                                    Text("New Knot")
                                    FloatPicker(value: $newUKnot)
                                    Button {
                                        surface.insert(uKnot: newUKnot)
                                    } label: { Text("Insert") }
                                }
                                BSplineBasisChart(basis: surface.uBasis)
                                    .frame(width: 400, height: 300).controlSize(.mini)
                            }
                        }
                        GroupBox ("V Basis") {
                            VStack {
                                HStack {
                                    Text("New Knot")
                                    FloatPicker(value: $newVKnot)
                                    Button {
                                        surface.insert(vKnot: newVKnot)
                                    } label: { Text("Insert") }
                                }
                                BSplineBasisChart(basis: surface.vBasis)
                                    .frame(width: 400, height: 300).controlSize(.mini)
                            }
                        }
                    }.padding()
                }
            }
            
            GroupBox {
                HStack {
                    VStack {
                        HStack {
                            TextField("U", value: $isoU, format: .number)
                            Button {
                                isocurveU = surface.isocurve(u: isoU)
                                isocurveU?.name = "iso u: \(isoU)"
                            } label: {
                                Text("Get")
                            }.disabled(!(surface.uBasis.knots.first!.value...surface.uBasis.knots.last!.value).contains(isoU))
                        }
                        if let isocurveU {
                            HStack {
                                Text("\(isocurveU.name)")
                                Button {
                                    isocurveU.name = drawables.uniqueName(name: isocurveU.name)
                                    drawables.insert(key: isocurveU.name, value: isocurveU)
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up").labelStyle(.iconOnly)
                                }.buttonStyle(.plain)
                            }
                        } else {
                            EmptyView()
                        }
                    }
                    VStack {
                        HStack {
                            TextField("V", value: $isoV, format: .number)
                            Button {
                                isocurveV = surface.isocurve(v: isoV)
                                isocurveV?.name = "iso v: \(isoV)"
                            } label: {
                                Text("Get")
                            }.disabled(!(surface.vBasis.knots.first!.value...surface.vBasis.knots.last!.value).contains(isoV))
                        }
                        if let isocurveV {
                            HStack {
                                Text("\(isocurveV.name)")
                                Button {
                                    isocurveV.name = drawables.uniqueName(name: isocurveV.name)
                                    drawables.insert(key: isocurveV.name, value: isocurveV)
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up").labelStyle(.iconOnly)
                                }.buttonStyle(.plain)
                            }
                        } else {
                            EmptyView()
                        }
                    }
                }.controlSize(.small)
                    .textFieldStyle(.roundedBorder)
            } label: {
                Text("Isocurves")
            }
            
            GroupBox {
                HStack {
                    Slider(value: tessellationFactor,
                           in: 1...64, step: 1,
                           label: { Text("") },
                           minimumValueLabel: { Text("1") },
                           maximumValueLabel: { Text("64") })
                    Stepper("", value: tessellationFactor,
                            in: 1...64, step: 1)
                }
            } label: {
                Text("Tessellation Factor \(Int(tessellationFactor.wrappedValue))")
                    .monospacedDigit()
            }
            
            GroupBox {
                BSplineSurfaceControlPointMatrix(surface: surface).frame(minHeight: 200)
            } label: {
                HStack {
                    Text("Control Points")
                    Toggle(isOn: .init(get: { surface.showControlNet }, 
                                       set: { show in surface.showControlNet = show })) {
                        Label("Show", systemImage: surface.showControlNet ? "eye.fill" : "eye.slash.fill")
                    }.toggleStyle(.button).labelStyle(.iconOnly).buttonStyle(.plain)
                    Spacer()
                    Button {
                        let points = surface.controlNet.flatMap { $0 }.map { SIMD3<Float>($0.x, $0.y, $0.z) / $0.w }
                        let pointSet = PointSet(points: points)
                        pointSet.name = drawables.uniqueName(name: "Control Net of \(surface.name)")
                        drawables.insert(key: pointSet.name, value: pointSet)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up").labelStyle(.iconOnly)
                    }.buttonStyle(.plain)
                }
            }.controlSize(.small)
        }
    }
    
    init(surface: BSplineSurface) {
        self.surface = surface
        self.tessellationFactor = .init(get: { surface.edgeTessellationFactors.x },
                                        set: { value in
                                            surface.edgeTessellationFactors = .init(repeating: value)
                                            surface.insideTessellationFactors = .init(repeating: value)
                                        })
    }
}

#Preview {
    BSplineSurfaceProperties(surface: BSplineSurface())
        .environment(DrawableCollection())
        .padding()
}
