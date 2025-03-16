//
//  SIMD2+UV.swift
//  Phantom
//
//  Created by TSAR Weasley on 2025/3/16.
//

import simd

extension SIMD2 {
    @inlinable public var u: Scalar { x }
    @inlinable public var v: Scalar { y }
    
    @inlinable public var s: Scalar { x }
    @inlinable public var t: Scalar { y }
}

extension SIMD3 {
    @inlinable public var u: Scalar { x }
    @inlinable public var v: Scalar { y }
    @inlinable public var w: Scalar { z }
    
    @inlinable public var s: Scalar { x }
    @inlinable public var t: Scalar { y }
    @inlinable public var p: Scalar { z }
}

extension SIMD4 {
    @inlinable public var u: Scalar { x }
    @inlinable public var v: Scalar { y }
    
    @inlinable public var s: Scalar { x }
    @inlinable public var t: Scalar { y }
    @inlinable public var p: Scalar { z }
    @inlinable public var q: Scalar { w }
}
