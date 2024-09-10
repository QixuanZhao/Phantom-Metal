//
//  LineSegmentsProperties.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/4/30.
//

import SwiftUI

struct LineSegmentsProperties: View {
    @Environment(\.self) private var environment
    
    var lineSegments: LineSegments
    
    @State private var colorStrategy: ColorStrategy = .mono
    @State private var color1: Color = .black
    @State private var color2: Color = .black
    @State private var error: Float = 0.1
        
    enum ColorStrategy {
        case mono, lengthLinear, lengthBinary, lengthLinearTruncated
    }
    
    var colorPickers: some View {
        HStack {
            ColorPicker("Color 1", selection: $color1)
            Spacer()
            if colorStrategy != .mono {
                ColorPicker("Color 2", selection: $color2)
            }
        }
        .onChange(of: color1) {
            let resolved = color1.resolve(in: environment)
            lineSegments.setColor(.init(Float(resolved.red),
                                        Float(resolved.green),
                                        Float(resolved.blue),
                                        Float(resolved.opacity)))
        }.onChange(of: color2) {
            let resolved1 = color1.resolve(in: environment)
            let resolved2 = color2.resolve(in: environment)
            lineSegments.setColor(.init(Float(resolved1.red),
                                        Float(resolved1.green),
                                        Float(resolved1.blue),
                                        Float(resolved1.opacity)),
                                  .init(Float(resolved2.red),
                                        Float(resolved2.green),
                                        Float(resolved2.blue),
                                        Float(resolved2.opacity))
            )
        }
    }
    
    var body: some View {
        Picker("Color Strategy", 
               selection: $colorStrategy) {
            Text("Mono").tag(ColorStrategy.mono)
            Text("Length (Binary)").tag(ColorStrategy.lengthBinary)
            Text("Length (Linear)").tag(ColorStrategy.lengthLinear)
            Text("Length (Linear T)").tag(ColorStrategy.lengthLinearTruncated)
        }.onChange(of: colorStrategy) {
            switch colorStrategy {
            case .mono:
                lineSegments.setColorStrategy(.mono)
            case .lengthLinear:
                lineSegments.setColorStrategy(.lengthLinear)
            case .lengthBinary:
                lineSegments.setColorStrategy(.lengthBinary(standard: error))
            case .lengthLinearTruncated:
                lineSegments.setColorStrategy(.lengthLinearTruncated(standard: error))
            }
        }
        
        if colorStrategy == .lengthBinary || colorStrategy == .lengthLinearTruncated {
            HStack {
                TextField("Error", value: $error, format: .number)
                Slider(value: $error, in: 0...1).onChange(of: error) {
                    if colorStrategy == .lengthBinary {
                        lineSegments.setColorStrategy(.lengthBinary(standard: error))
                    } else {
                        lineSegments.setColorStrategy(.lengthLinearTruncated(standard: error))
                    }
                }
            }.textFieldStyle(.roundedBorder)
        }
        
        colorPickers
        
        Spacer()
        
        if let passRate = lineSegments.passRate {
            Text("Pass Rate: \(passRate)").textSelection(.enabled)
        }
        Text("Max Length: \(lineSegments.maxLength)").textSelection(.enabled)
        Text("Min Length: \(lineSegments.minLength)").textSelection(.enabled)
        Text("Mean Length: \(lineSegments.meanLength)").textSelection(.enabled)
    }
    
    init(lineSegments: LineSegments) {
        self.lineSegments = lineSegments
        _error = switch lineSegments.colorBy {
        case .lengthBinary(let e):
            State(initialValue: e)
        case .lengthLinearTruncated(let e):
            State(initialValue: e)
        default:
            State(initialValue: 0.1)
        }
        
        _colorStrategy = switch lineSegments.colorBy {
        case .lengthLinearTruncated(_): .init(initialValue: .lengthLinearTruncated)
        case .lengthBinary(_): .init(initialValue: .lengthBinary)
        case .lengthLinear: .init(initialValue: .lengthLinear)
        case .mono: .init(initialValue: .mono)
        }
        
        _color1 = .init(initialValue: Color(red: Double(lineSegments.color1.x),
                                            green: Double(lineSegments.color1.y),
                                            blue: Double(lineSegments.color1.z),
                                            opacity: Double(lineSegments.color1.w)))
        
        _color2 = .init(initialValue: Color(red: Double(lineSegments.color2.x),
                                            green: Double(lineSegments.color2.y),
                                            blue: Double(lineSegments.color2.z),
                                            opacity: Double(lineSegments.color2.w)))
    }
}

#Preview {
    LineSegmentsProperties(lineSegments: LineSegments(segments: [
        (SIMD3<Float>.zero, SIMD3<Float>.one)
    ]))
}
