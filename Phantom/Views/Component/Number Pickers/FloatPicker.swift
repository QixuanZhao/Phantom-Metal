//
//  FloatPicker.swift
//  Metal 3D
//
//  Created by TSAR Weasley on 2023/11/9.
//

import SwiftUI

struct FloatPicker: View {
    @Binding var value: Float
    private(set) var range: ClosedRange<Float>?
    private(set) var integerLength: Int = 1
    private(set) var fractionLength: Int = 2
    private(set) var scale: Double = 1
    private(set) var step: Float = 0.1
    private(set) var placeHolder: String = "Value"
    
    @State private var tempValue: Float = 0
    @State var lastFrame: Date = .now
    @State private var firstDrag: Bool = true
    @State private var dy: Float = 0
    @State private var iconHovering: Bool = false
    
    @State private var uKnotValue: Float?
    @State private var vKnotValue: Float?
    
    var iconColor: Color { iconHovering || !firstDrag ? .secondary : .primary }
    
    private var displayString: String {
        var valueStr = value.formatted(
            .number
                .scale(scale)
                .precision(.integerAndFractionLength(integer: integerLength, fraction: fractionLength))
                .sign(strategy: .always(includingZero: true))
        )
        let tempValue = Double(value) * scale
        let sign = if tempValue < 0 { "-" } else { " " }
        if tempValue >= 0 {
            valueStr.remove(at: valueStr.startIndex)
            valueStr = sign + valueStr
        }
        
        
        let integer = if tempValue.isNaN || tempValue.isInfinite { 0 } else { Int(tempValue) }
        let integerDigits = if integer == 0 { 1 } else { Int(log10(abs(Float(integer)))) + 1 }
        
        if integerLength > 1 && integerLength > integerDigits {
            let padding = integerLength - integerDigits
            for _ in 0...padding { valueStr.remove(at: valueStr.startIndex) }
            valueStr = sign + valueStr
            valueStr = String(repeating: " ", count: padding) + valueStr
        }
        
        return valueStr
    }
    
    var body: some View {
        if let range {
            HStack {
                Stepper(value: $value, in: range, step: step) {
                    Text(displayString).monospaced()
                }
                Slider(value: $value, in: range)
            }
        } else {
            HStack (spacing: 0) {
                TextField(placeHolder, value: $value, format: .number)
                Stepper("", value: $value, step: step)
                Image(systemName: "dot.circle")
                    .foregroundStyle(iconColor)
                    .animation(.easeInOut, value: iconColor)
                    .onHover(perform: { hovering in
                        iconHovering = hovering
                        if hovering {
                            NSCursor.resizeUpDown.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    })
                    .transformEffect(.init(translationX: 0, y: firstDrag ? 0 : max(min(CGFloat(dy) / 5, 3.5), -3.5)))
                    .simultaneousGesture(
                        DragGesture(minimumDistance: .zero, coordinateSpace: .local)
                            .onChanged { value in
                                if firstDrag {
                                    firstDrag = false
                                    tempValue = self.value
                                }
                                let thisFrame = Date.now
                                let dt = thisFrame.timeIntervalSince(lastFrame)
                                if dt < 1.0 / 60 { return }
                                lastFrame = thisFrame
                                
                                dy = Float(value.translation.height)
                                self.value = tempValue - dy / Float(scale) * 0.1
                            }
                            .onEnded { _ in
                                firstDrag = true
                                tempValue = self.value
                            }
                    )
                    .padding(.horizontal, 5)
            }
        }
    }
}

#Preview {
    VStack {
        FloatPicker(value: .constant(.zero))
        FloatPicker(value: .constant(.zero), range: -1...1)
        FloatPicker(value: .constant(.zero))
    }
}
