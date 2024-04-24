//
//  BSplineBasisChart.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/14.
//

import SwiftUI
import Charts

extension BSplineBasis.IndexedKnot: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(knot)
        hasher.combine(firstIndex)
    }
    
    static func == (lhs: BSplineBasis.IndexedKnot, rhs: BSplineBasis.IndexedKnot) -> Bool {
        lhs.knot == rhs.knot && lhs.firstIndex == rhs.firstIndex
    }
}

struct BSplineBasisChart: View {
    let basis: BSplineBasis
    
    @State private var derivativeOrder: Int = 0
    @State private var showComputeGraph = false
    @State private var showChartExporter = false
    @State private var chartDocument: JSONDocument = .init()
    
    private var lowerbound: Float { min(basis.knots.first!.value, basis.knots.last!.value) }
    private var upperbound: Float { max(basis.knots.first!.value, basis.knots.last!.value) }
    
    private var colorStart: Color {
        Color.primary.opacity(0.4)
    }
    
    private var colorEnd: Color {
        if basis.requireUpdateBasis {
            Color.gray.opacity(0.8)
        } else { Color.accentColor.opacity(0.8) }
    }
    
    var body: some View {
        HStack {
            VStack {
                ScrollView (showsIndicators: false) {
                    VStack {
                        ForEach (basis.knots, id: \.id) { knot in
                            Text("\(knot.value) (\(knot.multiplicity))").font(.footnote)
                                .foregroundStyle(knot.multiplicity == basis.order ? Color.gray : Color.primary)
                        }
                        Spacer()
                    }
                }
                HStack {
                    Button {
                        showComputeGraph = true
                    } label: {
                        Label("Compute Graph", systemImage: "arrow.triangle.merge")
                    }.popover(isPresented: $showComputeGraph) {
                        ScrollView ([.horizontal, .vertical]) {
                            BSplineBasisComputeGraph(basis: basis)
                        }.frame(width: 1000)
                    }
                    
                    Button {
                        let samples = if derivativeOrder == 1 { basis.reader.firstDerivativeSamples }
                        else if derivativeOrder == 2 { basis.reader.secondDerivativeSamples }
                        else if derivativeOrder == 3 { basis.reader.thirdDerivativeSamples }
                        else { basis.reader.samples }
                        
                        if let data = JSONObjectParser.dump(samples: samples) {
                            chartDocument.json = String(decoding: data, as: UTF8.self)
                            showChartExporter = true
                        }
                    } label: {
                        Label("Export Chart", systemImage: "chart.xyaxis.line")
                    }.fileExporter(isPresented: $showChartExporter,
                                   document: chartDocument,
                                   contentType: .json) { result in
                        switch result {
                        case .success(let url):
                            print("save to \(url)")
                        case .failure(let error):
                            print(error.localizedDescription)
                        }
                    }
                }.labelStyle(.iconOnly).buttonStyle(.borderless)
            }
            
            VStack {
                Picker("Derivative Order", selection: $derivativeOrder) {
                    Text("0").tag(0)
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                if derivativeOrder == 0 {
                    Chart {
                        ForEach(basis.reader.samples) { intervalSample in
                            ForEach (intervalSample.samples) { functionSample in
                                ForEach (functionSample.samples, id: \.0) { (x, y) in
                                    LineMark(x: .value("u", x), y: .value("N", y))
                                        .foregroundStyle(by: .value("ID", functionSample.basisID))
                                }
                            }
                        }
                        
                        if !basis.reader.samples.isEmpty {
                            ForEach(basis.knots) { knot in
                                RuleMark(x: .value("knot", knot.value))
                                .foregroundStyle(Color.secondary.opacity(Double(knot.multiplicity) / Double(basis.order)))
                            }
                        }
                    }.chartLegend(.hidden).chartYScale(domain: 0...1)
                    .chartXScale(domain: lowerbound ... upperbound)
                    .chartForegroundStyleScale(range: Gradient(colors: [colorStart, colorEnd]))
                    .blur(radius: basis.reader.updated ? 0 : 10)
                } else {
                    Chart {
                        if derivativeOrder == 1 {
                            ForEach(basis.reader.firstDerivativeSamples) { intervalSample in
                                ForEach (intervalSample.samples) { functionSample in
                                    ForEach (functionSample.samples, id: \.0) { (x, y) in
                                        LineMark(x: .value("u", x), y: .value("N", y))
                                            .foregroundStyle(by: .value("ID", functionSample.basisID))
                                    }
                                }
                            }
                        } else if derivativeOrder == 2 {
                            ForEach(basis.reader.secondDerivativeSamples) { intervalSample in
                                ForEach (intervalSample.samples) { functionSample in
                                    ForEach (functionSample.samples, id: \.0) { (x, y) in
                                        LineMark(x: .value("u", x), y: .value("N", y))
                                            .foregroundStyle(by: .value("ID", functionSample.basisID))
                                    }
                                }
                            }
                        } else {
                            ForEach(basis.reader.thirdDerivativeSamples) { intervalSample in
                                ForEach (intervalSample.samples) { functionSample in
                                    ForEach (functionSample.samples, id: \.0) { (x, y) in
                                        LineMark(x: .value("u", x), y: .value("N", y))
                                            .foregroundStyle(by: .value("ID", functionSample.basisID))
                                    }
                                }
                            }
                        }
                        
                        if !basis.reader.samples.isEmpty {
                            ForEach(basis.knots) { knot in
                                RuleMark(x: .value("knot", knot.value))
                                .foregroundStyle(Color.secondary.opacity(Double(knot.multiplicity) / Double(basis.order)))
                            }
                        }
                    }.chartLegend(.hidden)
                    .chartXScale(domain: lowerbound ... upperbound)
                    .chartForegroundStyleScale(range: Gradient(colors: [colorStart, colorEnd]))
                    .blur(radius: basis.reader.updated ? 0 : 10)
                }
            }
        }.onChange(of: basis.requireUpdateBasis) {
            if !basis.requireUpdateBasis {
                basis.reader.read()
            }
        }.onAppear {
            basis.reader.read()
        }
    }
    
    init (basis: BSplineBasis) {
        self.basis = basis
    }
}

#Preview {
    BSplineBasisChart(basis: BSplineBasis())
}
