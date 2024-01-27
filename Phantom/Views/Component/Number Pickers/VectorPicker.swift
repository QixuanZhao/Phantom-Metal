//
//  VectorPicker.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/19.
//

import SwiftUI

struct VectorPicker: View {
    @Binding var value: SIMD3<Float>
    
    private(set) var boundingBox: (SIMD3<Float>, SIMD3<Float>)?
    private(set) var integerLength: Int = 1
    private(set) var fractionLength: Int = 2
    private(set) var scale: Double = 1
    private(set) var step: Float = 0.1
    private(set) var label: String = ""
    private(set) var systemImage: String = "slider.horizontal.2.square"
    
    var body: some View {
        GroupBox(label: Label(label, systemImage: systemImage)) {
            if let boundingBox {
                FloatPicker(value: $value.x, range: boundingBox.0.x...boundingBox.1.x, integerLength: integerLength, fractionLength: fractionLength, scale: scale, step: step)
                FloatPicker(value: $value.y, range: boundingBox.0.y...boundingBox.1.y, integerLength: integerLength, fractionLength: fractionLength, scale: scale, step: step)
                FloatPicker(value: $value.z, range: boundingBox.0.z...boundingBox.1.z, integerLength: integerLength, fractionLength: fractionLength, scale: scale, step: step)
            } else {
                FloatPicker(value: $value.x, integerLength: integerLength, fractionLength: fractionLength, scale: scale, step: step)
                FloatPicker(value: $value.y, integerLength: integerLength, fractionLength: fractionLength, scale: scale, step: step)
                FloatPicker(value: $value.z, integerLength: integerLength, fractionLength: fractionLength, scale: scale, step: step)
            }
        }
    }
}

#Preview {
    VStack {
        VectorPicker(value: .constant(.one), label: "A")
        VectorPicker(value: .constant(.zero), boundingBox: (-.one * 10, .one * 10), label: "旋转")
    }.padding()
}
