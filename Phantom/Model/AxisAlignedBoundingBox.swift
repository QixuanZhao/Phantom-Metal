//
//  AxisAlignedBoundingBox.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/1/4.
//

import simd

func * (_ lhs: (Float, Float), _ rhs: (Float, Float)) -> (Float, Float)? {
    let a = max(lhs.0, rhs.0)
    let b = min(lhs.1, rhs.1)
    return if a <= b { (a, b) } else { nil }
}

class AxisAlignedBoundingBox {
    var minimum: SIMD3<Float>
    var maximum: SIMD3<Float>
    
    var xSpan: (Float, Float) { (minimum.x, maximum.x) }
    var ySpan: (Float, Float) { (minimum.y, maximum.y) }
    var zSpan: (Float, Float) { (minimum.z, maximum.z) }
    
    var center: SIMD3<Float> { (minimum + maximum) / 2 }
    var diagonalLength: Float { distance(minimum, maximum) }
    
    init(diagonalVertices: (SIMD3<Float>, SIMD3<Float>)) {
        let a = diagonalVertices.0
        let b = diagonalVertices.1
        self.minimum = .init(x: min(a.x, b.x), y: min(a.y, b.y), z: min(a.z, b.z))
        self.maximum = .init(x: max(a.x, b.x), y: max(a.y, b.y), z: max(a.z, b.z))
    }
    
    static func * (_ a: AxisAlignedBoundingBox, _ b: AxisAlignedBoundingBox) -> AxisAlignedBoundingBox? {
        guard let newXSpan = a.xSpan * b.xSpan else { return nil }
        guard let newYSpan = a.ySpan * b.ySpan else { return nil }
        guard let newZSpan = a.zSpan * b.zSpan else { return nil }
        return .init(diagonalVertices: ([newXSpan.0, newYSpan.0, newZSpan.0], [newXSpan.1, newYSpan.1, newZSpan.1]))
    }
}
