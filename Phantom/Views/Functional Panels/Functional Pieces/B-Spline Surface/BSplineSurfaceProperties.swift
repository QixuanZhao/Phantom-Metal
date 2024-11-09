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
    
    @State private var isoU: Float = 0
    @State private var isoV: Float = 0
    
    @State private var isocurveU: BSplineCurve? = nil
    @State private var isocurveV: BSplineCurve? = nil
    
    @State private var removingUKnotValue: Float?
    @State private var removingVKnotValue: Float?
    
    @State private var showControlPointMatrix: Bool = true
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    showProjector = true
                } label: {
                    Text("Project/Inverse")
                }.popover(isPresented: $showProjector) {
                    TabView {
                        Tab {
                            CurvesToSurfaceProjectorView(viewModel: .init(drawables: drawables, surface: surface))
                                .frame(minWidth: 300).padding()
                        } label: { Text("Curves") }
                        Tab {
                            PointsToSurfaceProjectorView(viewModel: .init(drawables: drawables, surface: surface))
                                .frame(minWidth: 300).padding()
                        } label: { Text("Points") }
                    }.padding()
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
                                
                                HStack {
                                    Picker("Remove Knot: ", selection: $removingUKnotValue) {
                                        ForEach(surface.uBasis.knots) { knot in
                                            Text("\(knot.value)")
                                                .tag(knot.value)
                                        }
                                    }
                                    
                                    Button {
                                        guard removingUKnotValue != surface.uBasis.knots.first!.value
                                            && removingUKnotValue != surface.uBasis.knots.last!.value else {
                                            return
                                        }
                                        
                                        guard let removingUKnotValue else { return }
                                        
                                        showControlPointMatrix = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            let removedMultiplicity = surface.remove(uKnot: removingUKnotValue, for: 1, withTolerance: 1e-5)
                                            print("RM (S): \(removedMultiplicity)")
                                            showControlPointMatrix = true
                                        }
                                    } label: {
                                        Text("Confirm")
                                    }.disabled(removingUKnotValue == nil)
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
                                
                                HStack {
                                    Picker("Remove Knot: ", selection: $removingVKnotValue) {
                                        ForEach(surface.vBasis.knots) { knot in
                                            Text("\(knot.value)")
                                                .tag(knot.value)
                                        }
                                    }
                                    
                                    Button {
                                        guard removingVKnotValue != surface.vBasis.knots.first!.value
                                            && removingVKnotValue != surface.vBasis.knots.last!.value else {
                                            return
                                        }
                                        
                                        guard let removingVKnotValue else { return }
                                        
                                        showControlPointMatrix = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            let removedMultiplicity = surface.remove(vKnot: removingVKnotValue, for: 1, withTolerance: 1e-5)
                                            print("RM (S): \(removedMultiplicity)")
                                            showControlPointMatrix = true
                                        }
                                    } label: {
                                        Text("Confirm")
                                    }.disabled(removingVKnotValue == nil)
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
            
            if showControlPointMatrix {
                GroupBox {
                    BSplineSurfaceControlPointMatrix(surface: surface).frame(minHeight: 200)
                } label: {
                    HStack {
                        Text("Control Points \(surface.uBasis.controlPointCount) x \(surface.vBasis.controlPointCount)")
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
