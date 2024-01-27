//
//  MetalSystem.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/25.
//

import Metal

/**
 * System global variables.
 */
struct MetalSystem {
    let device: MTLDevice
}

let system = MetalSystem(device: MTLCreateSystemDefaultDevice()!)
