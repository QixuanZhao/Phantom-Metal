//
//  BSplineBasisComputeGraph.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/10.
//

import SwiftUI

struct BSplineBasisComputeGraph: View {
    let basis: BSplineBasis
    
    var body: some View {
        Grid (horizontalSpacing: 0) {
            GridRow {
                HStack { }
                ForEach (basis.knots, id: \.self) { knot in
                    Button {} label: {
                        HStack (spacing: .zero) {
                            Spacer()
                            Text("\(knot.value)")
                            Spacer()
                        }
                    }.gridCellColumns(knot.multiplicity * 4 - 1)
                    HStack { }
                }
            }.disabled(true)
            
            GridRow {
                HStack { }
                ForEach (0..<basis.multiplicitySum, id: \.self) { id in
                    HStack { }
                    HStack (alignment: .firstTextBaseline, spacing: 0) {
                        Text("t").font(.title3).italic()
                        Text("\(id)").font(.footnote)
                    }
                    HStack { }
                    HStack { }
                }
            }.padding(.bottom)
            
            ForEach(0...basis.degree, id: \.self) { degree in
                GridRow {
                    ForEach (0..<basis.knots.first!.multiplicity * 4 - degree * 2 - 1, id: \.self) { _ in
                        Image(systemName: "circle.dotted").hidden()
                    }
                    ForEach (1..<basis.knots.count, id: \.self) { knotIndex in
                        if basis.knots[knotIndex].multiplicity <= degree + 1 {
                            ForEach (0..<basis.knots[knotIndex].multiplicity, id: \.self) { id in
                                Image(systemName: "circle.dotted").hidden()
                                HStack (alignment: .firstTextBaseline, spacing: 0) {
                                    Text("N").font(.title2).italic()
                                    Text("\(id + basis.indexedKnots[knotIndex].firstIndex - degree - 1),\(degree)").font(.footnote)
                                }
                                Image(systemName: "circle.dotted").hidden()
                                Image(systemName: "circle.dotted").hidden()
                            }
                        } else {
                            ForEach (0 ..< degree + 1, id: \.self) { id in
                                Image(systemName: "circle.dotted").hidden()
                                HStack (alignment: .firstTextBaseline, spacing: 0) {
                                    Text("N").font(.title2).italic()
                                    Text("\(id + basis.indexedKnots[knotIndex].firstIndex - degree - 1),\(degree)").font(.footnote)
                                }
                                Image(systemName: "circle.dotted").hidden()
                                Image(systemName: "circle.dotted").hidden()
                            }
                            ForEach (degree + 1 ..< basis.knots[knotIndex].multiplicity, id: \.self) { _ in
                                Image(systemName: "circle.dotted").hidden()
                                Image(systemName: "circle.dotted").hidden()
                                Image(systemName: "circle.dotted").hidden()
                                Image(systemName: "circle.dotted").hidden()
                            }
                        }
                    }
                }
                if degree < basis.degree {
                    GridRow {
                        ForEach (0..<basis.knots.first!.multiplicity * 4 - degree * 2 - 2, id: \.self) { _ in
                            Image(systemName: "circle.dotted").hidden()
                        }
                        ForEach (1..<basis.knots.count, id: \.self) { knotIndex in
                            if basis.knots[knotIndex].multiplicity <= degree + 1 {
                                ForEach (0..<basis.knots[knotIndex].multiplicity, id: \.self) { id in
                                    Image(systemName: "circle.dotted").hidden()
                                    Image(systemName: "line.diagonal")
                                    Image(systemName: "circle.dotted").hidden()
                                    Image(systemName: "line.diagonal").rotationEffect(.degrees(90))
                                }
                            } else {
                                ForEach (0 ..< degree + 1, id: \.self) { id in
                                    Image(systemName: "circle.dotted").hidden()
                                    Image(systemName: "line.diagonal")
                                    Image(systemName: "circle.dotted").hidden()
                                    Image(systemName: "line.diagonal").rotationEffect(.degrees(90))
                                }
                                ForEach (degree + 1 ..< basis.knots[knotIndex].multiplicity, id: \.self) { _ in
                                    Image(systemName: "circle.dotted").hidden()
                                    Image(systemName: "circle.dotted").hidden()
                                    Image(systemName: "circle.dotted").hidden()
                                    Image(systemName: "circle.dotted").hidden()
                                }
                            }
                        }
                    }.foregroundStyle(Color.secondary)
                }
            }
            
        }.padding()
    }
}

#Preview {
    ScrollView ([.horizontal, .vertical]) {
        BSplineBasisComputeGraph(basis: BSplineBasis())
            .padding()
    }
}
