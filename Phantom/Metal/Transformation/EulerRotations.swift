//
//  EulerRotations.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/30.
//

import simd

struct EulerRotations {
    var roll:  Float
    var pitch: Float
    var yaw:   Float
    
    var pitchInRadians: Float { pitch * Float.pi / 180 }
    var yawInRadians:   Float { yaw   * Float.pi / 180 }
    var rollInRadians:  Float { roll  * Float.pi / 180 }
    
    var matrix: simd_float3x3 {
        simd_float3x3(rows: [
            SIMD3<Float>(cos(yawInRadians), -sin(yawInRadians), 0),
            SIMD3<Float>(sin(yawInRadians),  cos(yawInRadians), 0),
            SIMD3<Float>(0, 0, 1)
        ]) * simd_float3x3(rows: [
           SIMD3<Float>(1, 0, 0),
           SIMD3<Float>(0, cos(pitchInRadians), -sin(pitchInRadians)),
           SIMD3<Float>(0, sin(pitchInRadians),  cos(pitchInRadians))
        ]) * simd_float3x3(rows: [
            SIMD3<Float>(cos(rollInRadians), 0, -sin(rollInRadians)),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(sin(rollInRadians), 0, cos(rollInRadians))
        ])
    }
}
