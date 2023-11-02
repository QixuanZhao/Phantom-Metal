//
//  Drawable.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/19.
//

import simd
import Metal

protocol Drawable {
    func draw(_ encoder: MTLRenderCommandEncoder) -> Void
    static func initType(_ device: MTLDevice?) -> Void
    init(_ device: MTLDevice?)
}

protocol Model {
    var model: simd_float4x4 { get set }
    var translation: SIMD3<Float> { get set }
    var rotation: SIMD3<Float> { get set } // about x, y, z axes
    var scaling: SIMD3<Float> { get set }
}
