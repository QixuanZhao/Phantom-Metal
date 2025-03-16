//
//  BSplineBasisKnotEditor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/17.
//

import SwiftUI

extension BSplineBasis.Knot: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

struct BSplineBasisKnotEditor: View {
    @Binding var basis: BSplineBasis
    
//    @State private var lowerbound: Float = 0
//    @State private var upperbound: Float = 1
    @State private var innerKnots: Set<BSplineBasis.Knot>
    @State private var newKnot: Float = 0.5
    @State private var newKnotMultiplicity: Int = 1

    @State private var performTimestamp: Date = .now
    
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    Text("Degree: \(basis.degree)").monospacedDigit()
                    Spacer()
                    Text("Order: \(basis.degree + 1)").monospacedDigit()
                }
                HStack {
                    Slider(value: .init(get: { Double(basis.degree) }, set: { basis.degree = Int($0) }),
                           in: 1...16, step: 1,
                           label: { Text("") },
                           minimumValueLabel: { Text("1") },
                           maximumValueLabel: { Text("16") })
                    Stepper("", value: $basis.degree, in: 1...16, step: 1)
                }
            }
            HStack {
                TextField("lowerbound", value: $basis.knots.first!.value, format: .number)
                TextField("upperbound", value: $basis.knots.last!.value, format: .number)
            }.textFieldStyle(.roundedBorder)
            ScrollView {
                Table(of: BSplineBasis.Knot.self) {
                    TableColumn("Inner Knot") { knot in
                        if knot.multiplicity > 0 {
                            Text("\(knot.value)")
                        } else {
                            TextField("knot value", value: $newKnot, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }.width(ideal: 150)
                    TableColumn("Multiplicity") { knot in
                        if knot.multiplicity > 0 {
                            Text("\(knot.multiplicity)")
                        } else {
                            HStack {
                                Text("\(newKnotMultiplicity)")
                                Stepper("", value: $newKnotMultiplicity, in: 1...basis.degree, step: 1)
                            }
                        }
                    }.width(64)
                    TableColumn("Action") { knot in
                        if knot.multiplicity > 0 {
                            ControlGroup {
                                Button {
                                    guard let firstIndex = innerKnots.firstIndex(of: .init(value: knot.value, multiplicity: knot.multiplicity)) else {
                                        return
                                    }
                                    innerKnots.remove(at: firstIndex)
                                    innerKnots.insert(.init(value: knot.value, multiplicity: knot.multiplicity + 1))
                                } label: {
                                    Image(systemName: "plus")
                                }.disabled(knot.multiplicity >= basis.degree)
                                Button {
                                    guard let firstIndex = innerKnots.firstIndex(of: .init(value: knot.value, multiplicity: knot.multiplicity)) else {
                                        return
                                    }
                                    innerKnots.remove(at: firstIndex)
                                    if knot.multiplicity > 1 {
                                        innerKnots.insert(.init(value: knot.value, multiplicity: knot.multiplicity - 1))
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                }
                            }
                        } else {
                            Button {
                                if newKnot == basis.knots.first!.value || newKnot == basis.knots.last!.value { return }
                                
                                if let firstIndex = innerKnots.firstIndex(where: { $0.value == newKnot }) {
                                    if innerKnots[firstIndex].multiplicity < basis.degree {
                                        let multiplicity = min(innerKnots[firstIndex].multiplicity + newKnotMultiplicity, basis.degree)
                                        innerKnots.remove(at: firstIndex)
                                        innerKnots.insert(.init(value: newKnot, multiplicity: multiplicity))
                                    }
                                } else {
                                    innerKnots.insert(.init(value: newKnot, multiplicity: newKnotMultiplicity))
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "plus")
                                    Spacer()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(newKnot <= basis.knots.first!.value || newKnot >= basis.knots.last!.value)
                        }
                    }.width(40)
                } rows: {
                    TableRow(BSplineBasis.Knot(value: 0, multiplicity: -1))
                    ForEach (innerKnots.sorted(by: { $0.value < $1.value })) { knot in
                        TableRow(knot)
                    }
                }.frame(minHeight: 200)
            }.frame(minHeight: 200)
        }
        .controlSize(.small)
        .onChange(of: innerKnots) {
            var tempKnots = [basis.knots.first!]
            tempKnots.append(contentsOf: innerKnots.sorted(by: { $0.value < $1.value }))
            tempKnots.append(basis.knots.last!)
            basis.knots = tempKnots
        }.onChange(of: basis.degree) {
            basis.knots[0].multiplicity = basis.degree + 1
            basis.knots[basis.knots.count - 1].multiplicity = basis.degree + 1
        }.onChange(of: basis.knots) {
            performTimestamp = .now + MetalSystem.shared.debounceInterval
            Timer.scheduledTimer(withTimeInterval: MetalSystem.shared.debounceInterval,
                                 repeats: false) { _ in
                Task {
                    await MainActor.run {
                        if Date.now >= performTimestamp {
                            basis.updateTexture()
                        }
                    }
                }
            }
        }
    }
    
    
    init(basis: Binding<BSplineBasis>) {
        _basis = basis
        _innerKnots = State(initialValue: .init(basis.wrappedValue.knots.filter { $0.multiplicity < basis.wrappedValue.order }))
    }
}

#Preview {
    BSplineBasisKnotEditor(basis: .constant(BSplineBasis(degree: 3,
                                                         knots: [
                                                            .init(value: 0, multiplicity: 4),
                                                            .init(value: 1, multiplicity: 4)
                                                         ]))).padding()
}
