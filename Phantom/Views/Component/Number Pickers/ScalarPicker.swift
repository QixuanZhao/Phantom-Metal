//
//  ScalarPicker.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/19.
//

import SwiftUI

struct ScalarPicker: View {
    @Binding var value: Float
    private(set) var range: ClosedRange<Float>?
    private(set) var integerLength: Int = 1
    private(set) var fractionLength: Int = 2
    private(set) var scale: Double = 1
    private(set) var step: Float = 0.1
    private(set) var label: String = ""
    private(set) var systemImage: String = "slider.horizontal.2.square"
    
    var body: some View {
        GroupBox(label: Label(label, systemImage: systemImage)) {
            FloatPicker(value: $value, 
                        range: range,
                        integerLength: integerLength,
                        fractionLength: fractionLength,
                        scale: scale,
                        step: step)
        }
    }
}

#Preview {
    ScalarPicker(value: .constant(.zero), label: "label")
}
