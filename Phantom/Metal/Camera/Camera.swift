//
//  Camera.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/16.
//

import simd
import SwiftUI

class Camera: ObservableObject {
    var position: SIMD3<Float> = SIMD3<Float>(0, -2, 1)
    var right: SIMD3<Float> { eularAngleTransformation[0] }
    var front: SIMD3<Float> { eularAngleTransformation[1] }
    var up:    SIMD3<Float> { eularAngleTransformation[2] }
    var view: simd_float4x4 {
        let r = simd_float4x4(rows: [
            SIMD4<Float>(right, 0),
            SIMD4<Float>(up, 0),
            SIMD4<Float>(-front, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ])
        
        var t = simd_float4x4(diagonal: .one)
        t[3] = SIMD4<Float>(-position, 1)
        return r * t
    }
    
    var resolution: CGSize?
    var projection: simd_float4x4 {
        let aspectRatio: Float = if let resolution { Float(resolution.width / resolution.height) } else { 1.0 }
        let tangentTheta = tan(22.5 * Float.pi / 180)
        let tangentPhi: Float = tangentTheta * aspectRatio
        return simd_float4x4(rows: [
            SIMD4<Float>(1 / tangentPhi, 0, 0, 0),
            SIMD4<Float>(0, 1 / tangentTheta, 0, 0),
            SIMD4<Float>(0, 0, -10.0 / 9.9, -1 / 9.9),
            SIMD4<Float>(0, 0, -1, 0)
        ])
    }
    
    private var eularAngleTransformation: simd_float3x3 {
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
    
    private var pitchInRadians: Float { pitch * Float.pi / 180 }
    private var yawInRadians:   Float { yaw   * Float.pi / 180 }
    private var rollInRadians:  Float { roll  * Float.pi / 180 }
    
    // Eular Angles
    var pitch: Float = -20 {
        didSet {
            if pitch >= 90.0 {
                pitch = 90
            } else if pitch <= -90.0 {
                pitch = -90
            }
        }
    }
    var yaw: Float = 0 {
        didSet {
            if yaw >= 180 {
                yaw = yaw - 360
            } else if yaw <= -180 {
                yaw = yaw + 360
            }
        }
    }
    var roll: Float = 0 {
        didSet {
            if roll >= 180 {
                roll = roll - 360
            } else if roll <= -180 {
                roll = roll + 360
            }
        }
    }
    
    var controller: CameraController?
}
