//
//  MetalSystem.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/25.
//

import Metal
import SwiftUI

enum MetalError: Error {
    case cannotMakeCommandBuffer
    case cannotMakeBuffer
    case cannotMakeComputeCommandEncoder
}

/**
 * System properties. (or
 * Application properties.
 */
struct MetalSystem {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    let defaultMaterial: Material
    
    let width = NSScreen.main!.frame.width * NSScreen.main!.backingScaleFactor
    let height = NSScreen.main!.frame.height * NSScreen.main!.backingScaleFactor
    
    let depthTextureDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
    let geometryTextureDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
    let hdrTextureDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
    
    let debounceInterval: Double = 0.75
    
    init(device: MTLDevice, defaultMaterial: Material) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.commandQueue.label = "Phantom Command Queue"
        self.library = device.makeDefaultLibrary()!
        self.defaultMaterial = defaultMaterial
        
        depthTextureDescriptor.width = Int(width)
        depthTextureDescriptor.height = Int(height)
        depthTextureDescriptor.pixelFormat = .depth32Float
        depthTextureDescriptor.usage = .renderTarget
        depthTextureDescriptor.storageMode = .memoryless
        
        geometryTextureDescriptor.width = Int(width)
        geometryTextureDescriptor.height = Int(height)
        geometryTextureDescriptor.pixelFormat = .rgba32Float
        geometryTextureDescriptor.usage = [.renderTarget, .shaderRead]
        geometryTextureDescriptor.storageMode = .memoryless
        
        hdrTextureDescriptor.width = Int(width)
        hdrTextureDescriptor.height = Int(height)
        hdrTextureDescriptor.pixelFormat = .rgba32Float
        hdrTextureDescriptor.usage = [.renderTarget, .shaderRead]
        hdrTextureDescriptor.storageMode = .private
    }
}

// global system variable(s)
let system = MetalSystem(device: MTLCreateSystemDefaultDevice()!,
                         defaultMaterial: Material(albedoSpecular: [1, 1, 1, 0.9],
                                                   refractiveIndicesRoughnessU: [1.5, 1.5, 1.5, 0.7],
                                                   extinctionCoefficentsRoughnessV: [1, 1, 1, 0.7])
)

let defaultMaterialWrapper = MaterialWrapper(material: system.defaultMaterial)

enum PhantomError: Error {
    case unknown(String)
}
