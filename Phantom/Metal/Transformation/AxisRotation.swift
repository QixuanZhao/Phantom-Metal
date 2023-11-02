//
//  QuaternionRotation.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/30.
//

import simd

struct AxisRotation {
    var axis: SIMD3<Float>
    var angle: Float // in degrees
    
    var normalAxis: SIMD3<Float> { axis / length(axis) }
    
    var angleInRadians: Float {
        get { angle * Float.pi / 180 }
        set (radians) { angle = radians * 180 / Float.pi }
    }
    
    var quaternion: simd_quatf {
        get { simd_quatf(angle: angleInRadians, axis: normalAxis) }
        set (quaternion) {
            axis = quaternion.axis
            angleInRadians = quaternion.angle
        }
    }
    
    var matrix: simd_float3x3 {
        let aat = simd_float3x3(rows: [
            normalAxis.x * normalAxis,
            normalAxis.y * normalAxis,
            normalAxis.z * normalAxis
        ])
        let I = simd_float3x3(diagonal: .one)
        let ax = simd_float3x3(rows: [
            SIMD3<Float>(0, -normalAxis.z, normalAxis.y),
            SIMD3<Float>(normalAxis.z, 0, -normalAxis.x),
            SIMD3<Float>(-normalAxis.y, normalAxis.x, 0)
        ])
        return (I - aat) * cos(angleInRadians) + ax * sin(angleInRadians) + aat
    }
}
