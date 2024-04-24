//
//  BernsteinBasisChart.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import SwiftUI
import Charts

extension BernsteinBasis {
    var samples: [FunctionSample] { reader.samples }
    var derivativeSamples: [FunctionSample] { reader.derivativeSamples }
}

struct BernsteinBasisChart: View {
    let basis: BernsteinBasis
    
    @State private var showDerivatives = false
    
    private var colorStart: Color {
        Color.primary.opacity(0.4)
    }
    
    private var colorEnd: Color {
        if basis.requireRecreateBasisTexture {
            Color.gray.opacity(0.8)
        } else { Color.accentColor.opacity(0.8) }
    }
    
    var body: some View {
        VStack {
            Toggle (isOn: $showDerivatives) {
                HStack {
                    Spacer()
                    Text(showDerivatives ? "Derivatives" : "Basis")
                    Spacer()
                }
            }.toggleStyle(.button)
            if showDerivatives {
                Chart {
                    ForEach(basis.derivativeSamples) {  functionSample in
                        ForEach (functionSample.samples, id: \.0) { (x, y) in
                            LineMark(x: .value("u", x), y: .value("N", y))
                                .foregroundStyle(by: .value("ID", functionSample.basisID))
                        }
                    }
                }.chartLegend(.hidden).blur(radius: basis.reader.updated ? 0 : 10)
                .chartForegroundStyleScale(range: Gradient(colors: [colorStart,
                                                                     colorEnd]))
            } else {
                Chart {
                    ForEach(basis.samples) { functionSample in
                        ForEach (functionSample.samples, id: \.0) { (x, y) in
                            LineMark(x: .value("u", x), y: .value("N", y))
                                .foregroundStyle(by: .value("ID", functionSample.basisID))
                        }
                    }
                }.chartLegend(.hidden).chartYScale(domain: [0, 1])
                .blur(radius: basis.reader.updated ? 0 : 10)
                .chartForegroundStyleScale(range: Gradient(colors: [colorStart,
                                                                     colorEnd]))
            }
        }.onChange(of: basis.requireRecreateBasisTexture) {
            if !basis.requireRecreateBasisTexture {
                basis.reader.read()
            }
        }.onAppear {
            basis.reader.read()
        }
    }
    
    init(basis: BernsteinBasis) {
        self.basis = basis
    }
}

#Preview {
    BernsteinBasisChart(basis: BernsteinBasis(degree: 3))
        .frame(width: 230, height: 200).padding()
}
