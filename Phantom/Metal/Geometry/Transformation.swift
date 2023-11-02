//
//  ModelTransformation.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/19.
//

import simd

class Transformation: Model {
    var model: simd_float4x4 = simd_float4x4(diagonal: .one)
    
    private var requireUpdate = false
    
    func updateModel() {
        if !requireUpdate { return }
        let scale = simd_float4x4(diagonal: SIMD4<Float>(scaling, 1))
        let rotate = simd_float4x4(rows: [
            SIMD4<Float>( cos(rotationInRadians.y), 0, sin(rotationInRadians.y), 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(-sin(rotationInRadians.y), 0, cos(rotationInRadians.y), 0),
            SIMD4<Float>(0, 0, 0, 1),
        ]) * simd_float4x4(rows: [
            SIMD4<Float>(cos(rotationInRadians.z), -sin(rotationInRadians.z), 0, 0),
            SIMD4<Float>(sin(rotationInRadians.z),  cos(rotationInRadians.z), 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1),
        ]) * simd_float4x4(rows: [
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, cos(rotationInRadians.x), -sin(rotationInRadians.x), 0),
            SIMD4<Float>(0, sin(rotationInRadians.x),  cos(rotationInRadians.x), 0),
            SIMD4<Float>(0, 0, 0, 1),
        ])
        var translate = simd_float4x4(diagonal: .one)
        translate[3] = SIMD4<Float>(translation, 1)
        
        model = translate * rotate * scale
        requireUpdate = false
    }
    
    var rotationInRadians: SIMD3<Float> {
        rotation * Float.pi / 180
    }
    
    var translation: SIMD3<Float> = .zero { didSet { requireUpdate = true }}
    var rotation: SIMD3<Float> = .zero { didSet { requireUpdate = true }}
    var scaling: SIMD3<Float> = .one { didSet { requireUpdate = true }}
}
