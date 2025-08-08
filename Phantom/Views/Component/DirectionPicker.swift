//
//  DirectionPicker.swift
//  Phantom
//
//  Created by Rachel on 2025/8/7.
//

import simd
import SwiftUI

extension DirectionPicker {
    struct HorizontalCoordinate: Equatable {
        var azimuth: Angle
        var altitude: Angle
    }
}

struct DirectionPicker: View {
    @Binding var direction: SIMD3<Float>
    @State var coord: HorizontalCoordinate
    
    init(direction: Binding<SIMD3<Float>>) {
        let d = normalize(direction.wrappedValue)
        _direction = direction
        
        self.coord = .init(
            azimuth: Angle(radians: Double(atan2(d.y, d.x))),
            altitude: Angle(radians: Double(asin(d.z)))
        )
    }
    
    var body: some View {
        HStack {
            AnglePicker(angle: $coord.azimuth, title: "Azimuth")
            AnglePicker(angle: $coord.altitude, title: "Altitude")
        }
        .onChange(of: coord, initial: true) {
            direction = .init(
                x: Float(cos(coord.azimuth.radians) * cos(coord.altitude.radians)),
                y: Float(sin(coord.azimuth.radians) * cos(coord.altitude.radians)),
                z: Float(sin(coord.altitude.radians))
            )
        }
    }
}

#Preview {
    DirectionPicker(
        direction: .constant(.one)
    )
    .padding()
}
