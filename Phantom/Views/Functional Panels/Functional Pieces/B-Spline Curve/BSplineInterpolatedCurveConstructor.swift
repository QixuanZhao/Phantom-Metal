//
//  BSplineInterpolatedCurveConstructor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/24.
//

import simd
import SwiftUI

struct BSplineInterpolatedCurveConstructor: View {
    @Environment(DrawableCollection.self) private var drawables
    
    @State private var showConstructor = false
    @State private var specifyingParameters = false
    @State private var interpolatees: [Interpolatee] = []
    @State private var newInterpolatee: Interpolatee = .init(id: 0, position: .zero, parameter: .zero)
    @State private var degree: Int = 3
    
    struct Interpolatee: Identifiable {
        var id: Int
        var position: SIMD3<Float>
        var parameter: Float
    }
    
    private var actualDegree: Int { min(degree, interpolatees.count - 1) }
    
    var body: some View {
        Button {
            showConstructor = true
        } label: {
            Label("Interpolated Curve", systemImage: "pencil.and.ruler")
        }.popover(isPresented: $showConstructor) {
            VStack (alignment: .leading) {
                HStack {
                    GroupBox {
                        VStack {
                            TextField("Parameter",
                                      value: .init(get: { newInterpolatee.parameter },
                                                   set: { newInterpolatee.parameter = max(min($0, 1), 0) }),
                                      format: .number)
                            Slider(value: .init(get: { newInterpolatee.parameter },
                                                set: { newInterpolatee.parameter = $0 }),
                                   in: 0...1)
                        }.disabled(!specifyingParameters)
                    } label: {
                        Toggle(isOn: $specifyingParameters) {
                            Text("Specifying Parameters")
                        }.toggleStyle(.switch).controlSize(.mini)
                            .foregroundStyle(specifyingParameters ? .primary : .secondary)
                    }
                    
                    VStack {
                        HStack {
                            Text("X")
                            TextField("X",
                                      value: .init(get: { newInterpolatee.position.x },
                                                   set: { newInterpolatee.position.x = $0 }),
                                      format: .number)
                        }
                        HStack {
                            Text("Y")
                            TextField("Y",
                                      value: .init(get: { newInterpolatee.position.y },
                                                   set: { newInterpolatee.position.y = $0 }),
                                      format: .number)
                        }
                        HStack {
                            Text("Z")
                            TextField("Z",
                                      value: .init(get: { newInterpolatee.position.z },
                                                   set: { newInterpolatee.position.z = $0 }),
                                      format: .number)
                        }
                    }
                }
                Button {
                    interpolatees.append(newInterpolatee)
                    newInterpolatee.id = newInterpolatee.id + 1
                } label: {
                    HStack (alignment: .center) {
                        Label("Add Interpolatee", systemImage: "plus")
                        Divider()
                        if specifyingParameters {
                            Text("at \(newInterpolatee.parameter)")
                        }
                        Spacer()
                        VStack (alignment: .trailing) {
                            Text("\(newInterpolatee.position.x)")
                            Text("\(newInterpolatee.position.y)")
                            Text("\(newInterpolatee.position.z)")
                        }
                    }
                }.controlSize(.small)
                
                Table(interpolatees) {
                    TableColumn("#") { Text("\($0.id)") }.width(15)
                    TableColumn("Position") { item in
                        Text("\(item.position.x)")
                        Text("\(item.position.y)")
                        Text("\(item.position.z)")
                    }
                    TableColumn(specifyingParameters ? "Parameter" : "-") {
                        if specifyingParameters {
                            Text("\($0.parameter)")
                        }
                    }
                    TableColumn("Operation") { item in
                        Button {
                            interpolatees.removeAll(where: { $0.id == item.id })
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        ControlGroup {
                            Button {
                                let index = interpolatees.firstIndex { $0.id == item.id }!
                                if index > interpolatees.startIndex {
                                    interpolatees.move(fromOffsets: [index],
                                                       toOffset: interpolatees.index(before: index))
                                }
                            } label: {
                                Label("Move", systemImage: "arrow.up")
                            }.disabled(interpolatees.first!.id == item.id)
                            Button {
                                let index = interpolatees.firstIndex { $0.id == item.id }!
                                if index < interpolatees.endIndex {
                                    interpolatees.move(fromOffsets: [interpolatees.index(after: index)],
                                                       toOffset: index)
                                }
                            } label: {
                                Label("Move", systemImage: "arrow.down")
                            }.disabled(interpolatees.last!.id == item.id)
                        }
                    }
                }.frame(minWidth: 400, minHeight: 300)
                    .controlSize(.small)
                
                HStack {
                    Text("Interpolatee Count: \(interpolatees.count)")
                    Spacer()
                    Text("Mind the Order").foregroundStyle(.mint)
                }
                
                HStack {
                    Text("Maximum Degree: \(interpolatees.count - 1)")
                    Spacer()
                    Stepper("Recommanded Degree: \(degree)", value: $degree, in: 1...16)
                }
                
                Button {
                    do {
                        var interpolationResult: BSplineInterpolator.InterpolationResult
                        if specifyingParameters {
                            interpolationResult = try BSplineInterpolator.interpolate(points: interpolatees.map { $0.position },
                                                                parameters: interpolatees.map { $0.parameter },
                                                                idealDegree: actualDegree)
                        } else {
                            interpolationResult = try BSplineInterpolator.interpolate(points: interpolatees.map { $0.position },
                                                                idealDegree: actualDegree)
                        }
                        
                        interpolationResult.curve.name = drawables.uniqueName(name: "Interpolated Curve")
                        drawables.insert(key: interpolationResult.curve.name, value: interpolationResult.curve)
                    } catch {
                        print(error.localizedDescription)
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Confirm with Degree \(actualDegree)")
                        Spacer()
                    }
                }.disabled(actualDegree < 1)
            }.padding().textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    BSplineInterpolatedCurveConstructor()
        .environment(DrawableCollection())
        .padding()
}
