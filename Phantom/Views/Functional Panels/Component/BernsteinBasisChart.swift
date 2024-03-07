//
//  BernsteinBasisChart.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/3.
//

import SwiftUI
import Charts

extension BernsteinBasis {
    var samples: [BernsteinBasisReader.FunctionSample] { reader.samples }
    var derivativeSamples: [BernsteinBasisReader.FunctionSample] { reader.derivativeSamples }
}

struct BernsteinBasisChart: View {
    let basis: BernsteinBasis
    
    @State private var showDerivatives = false
    
    private var blurRadius: Float {
        if basis.reader.busy { 10 }
        else { 0 }
    }
    
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
                }.chartLegend(.hidden).blur(radius: CGFloat(blurRadius))
                .overlay {
                    if basis.reader.busy {
                        ProgressView()
                    }
                }.chartForegroundStyleScale(range: Gradient(colors: [colorStart,
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
                .blur(radius: CGFloat(blurRadius))
                .overlay {
                    if basis.reader.busy {
                        ProgressView()
                    }
                }.chartForegroundStyleScale(range: Gradient(colors: [colorStart,
                                                                     colorEnd]))
            }
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
