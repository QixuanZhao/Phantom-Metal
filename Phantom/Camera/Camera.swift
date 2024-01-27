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
    
    var aspectRatio: Float = 1
    var fov: Float = 45
    var far: Float = 100
    var near: Float = 1
    var projection: simd_float4x4 {
        let tangentTheta = tan(fov * Float.pi / 360)
        let tangentPhi: Float = tangentTheta * aspectRatio
        return simd_float4x4(rows: [
            SIMD4<Float>(1 / tangentPhi, 0, 0, 0),
            SIMD4<Float>(0, 1 / tangentTheta, 0, 0),
            SIMD4<Float>(0, 0, -far / (far - near), -far * near / (far - near)),
            SIMD4<Float>(0, 0, -1, 0)
        ])
    }
    
    private var eularAngleTransformation: simd_float3x3 {
        let yaw = yaw * Float.pi / 180
        let pitch = pitch * Float.pi / 180
        let roll = roll * Float.pi / 180
        
        return simd_float3x3(rows: [
            SIMD3<Float>(cos(yaw), -sin(yaw), 0),
            SIMD3<Float>(sin(yaw),  cos(yaw), 0),
            SIMD3<Float>(0, 0, 1)
        ]) * simd_float3x3(rows: [
           SIMD3<Float>(1, 0, 0),
           SIMD3<Float>(0, cos(pitch), -sin(pitch)),
           SIMD3<Float>(0, sin(pitch),  cos(pitch))
        ]) * simd_float3x3(rows: [
            SIMD3<Float>(cos(roll), 0, -sin(roll)),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(sin(roll), 0, cos(roll))
        ])
    }
    
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
}
