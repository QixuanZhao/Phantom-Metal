//
//  Vertex.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/17.
//

import simd

struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var color: SIMD4<Float>
    
    init(position: SIMD3<Float>, normal: SIMD3<Float>, color: SIMD4<Float>) {
        self.position = position
        self.normal = normal
        self.color = color
    }
    
    init(position: SIMD3<Float>, color: SIMD4<Float>) {
        self.position = position
        self.normal = .zero
        self.color = color
    }
}

struct Uniform {
    var view: simd_float4x4
    var projection: simd_float4x4
    var cameraPosition: SIMD3<Float>
}

let iVertex  = 0
let iUniform = 1
let iModel   = 2
