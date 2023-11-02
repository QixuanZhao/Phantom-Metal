//
//  Renderer.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/11.
//

import SwiftUI
import MetalKit

class Renderer: NSObject, MTKViewDelegate, ObservableObject {
    private var device = MTLCreateSystemDefaultDevice()
    private var commandQueue: MTLCommandQueue?
    
    var lastFrameTimestamp: Date = .now
    var backgroundColor: Color.Resolved?
    @Published var fps: Double = 0.0
    var resolution: CGSize = .zero
    
    private var renderPipelineState: MTLRenderPipelineState?
    private var depthStencilState: MTLDepthStencilState?
    private var uniformBuffer: MTLBuffer?
    private var depthTexture: MTLTexture?
    
    private(set) var camera = Camera()
    var controller = FPSCameraController()
    
    var rgbTriangle: RGBTriangle!
    private var square: Square!
    private var axes: Axes!
    
    func initMtl(_ view: MTKView) {
        view.delegate = self
        
        if let device {
            print("GPU: \(device.name)")
            print("GPU Architecture: \(device.architecture.name)")
            print("Programmable Sample Positions: \(device.areProgrammableSamplePositionsSupported)")
            print("Raster Order Groups: \(device.areRasterOrderGroupsSupported)")
            print("Argument Buffers: \(device.argumentBuffersSupport)")
            print("Current Allocated Size: \(device.currentAllocatedSize) B")
            print("Unified Memory: \(device.hasUnifiedMemory)")
            print("D24S8 Supported: \(device.isDepth24Stencil8PixelFormatSupported)")
            print("Headless (not connecting to a display): \(device.isHeadless)")
            print("Low Power Mode: \(device.isLowPower)")
            print("Removable: \(device.isRemovable)")
            print("Location #: \(device.locationNumber)")
            print("Max Argument Buffer Sampler Count: \(device.maxArgumentBufferSamplerCount)")
            print("Max Buffer Length: \(device.maxBufferLength) B")
            print("Max Threadgroup Memory Length: \(device.maxThreadgroupMemoryLength) B")
            print("Max Transfer Rate: \(device.maxTransferRate) B/s")
            print("Max Concurrent Compilation Task Count: \(device.maximumConcurrentCompilationTaskCount)")
            print("Peer Count: \(device.peerCount)")
            print("Peer Group ID: \(device.peerGroupID)")
            print("Peer Index: \(device.peerIndex)")
            print("Recommended Max Working Set Size: \(device.recommendedMaxWorkingSetSize) B")
            print("Registry ID: \(device.registryID)")
            print("Should Maximize Concurrent Compilation: \(device.shouldMaximizeConcurrentCompilation)")
            print("Sparse Tile Size: \(device.sparseTileSizeInBytes) B")
            print("32b Float Filtering: \(device.supports32BitFloatFiltering)")
            print("32b MSAA: \(device.supports32BitMSAA)")
            print("BC Texture Compression: \(device.supportsBCTextureCompression)")
            print("Dynamic Libraries: \(device.supportsDynamicLibraries)")
            print("Render Dynamic Libraries: \(device.supportsRenderDynamicLibraries)")
            print("Function Pointers: \(device.supportsFunctionPointers)")
            print("Render Function Pointers: \(device.supportsFunctionPointersFromRender)")
            print("Motion Blur for RT: \(device.supportsPrimitiveMotionBlur)")
            print("Pull Model Interpolation: \(device.supportsPullModelInterpolation)")
            print("Query Texture LOD: \(device.supportsQueryTextureLOD)")
            print("RT: \(device.supportsRaytracing)")
            print("Shader RT: \(device.supportsRaytracingFromRender)")
            print("Barycentric Coordinates: \(device.supportsShaderBarycentricCoordinates)")
            view.device = device
        }
        
        self.commandQueue = device?.makeCommandQueue()
        
        self.uniformBuffer = device?.makeBuffer(length: MemoryLayout<Uniform>.size, options: .storageModeShared)
        
        let depthTextureDescriptor = MTLTextureDescriptor()
        depthTextureDescriptor.width = Int(10)
        depthTextureDescriptor.height = Int(10)
        depthTextureDescriptor.pixelFormat = .depth32Float
        depthTextureDescriptor.usage = .renderTarget
        depthTextureDescriptor.storageMode = .private
        self.depthTexture = device?.makeTexture(descriptor: depthTextureDescriptor)
        
        if let device {
            Square.initType(device)
            Axes.initType(device)
            RGBTriangle.initType(device)
            
            square = Square(device)
            axes = Axes(device)
            rgbTriangle = RGBTriangle(device)
        }
        
        let defaultLibrary = device?.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShader")
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        let vertexDescriptor = MTLVertexDescriptor()
        // position of triangle vertices
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = MemoryLayout<Vertex>.offset(of: \.position)!
        
        // normal of triangle vertices
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<Vertex>.offset(of: \.normal)!
        
        // color of triangle vertices
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[2].offset = MemoryLayout<Vertex>.offset(of: \.color)!
        
        // layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.vertexFunction = vertexFunction
        // fragmentFunction.
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        self.renderPipelineState = try? device?.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        self.depthStencilState = device?.makeDepthStencilState(descriptor: depthStencilDescriptor)
        camera.controller = controller
        controller.camera = camera
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.resolution = size
        camera.resolution = size
        
        let depthTextureDescriptor = MTLTextureDescriptor()
        depthTextureDescriptor.width = Int(size.width)
        depthTextureDescriptor.height = Int(size.height)
        depthTextureDescriptor.pixelFormat = .depth32Float
        depthTextureDescriptor.usage = .renderTarget
        depthTextureDescriptor.storageMode = .private
        self.depthTexture = device?.makeTexture(descriptor: depthTextureDescriptor)
    }
    
    func draw(in view: MTKView) {
        let currentFrameTimestamp = Date.now
        let timeInterval = currentFrameTimestamp.timeIntervalSince(lastFrameTimestamp)
        lastFrameTimestamp = currentFrameTimestamp
        
        self.fps = 1.0 / timeInterval
        
        if let backgroundColor {
            view.clearColor = MTLClearColorMake(
                Double(backgroundColor.red),
                Double(backgroundColor.green),
                Double(backgroundColor.blue),
                Double(backgroundColor.opacity))
        }
        view.clearDepth = 1.0
        
        controller.update(Float(timeInterval))
        
        self.uniformBuffer?.contents().storeBytes(of: camera.view, toByteOffset: MemoryLayout<Uniform>.offset(of: \.view)!, as: simd_float4x4.self)
        self.uniformBuffer?.contents().storeBytes(of: camera.projection, toByteOffset: MemoryLayout<Uniform>.offset(of: \.projection)!, as: simd_float4x4.self)
        self.uniformBuffer?.contents().storeBytes(of: camera.position, toByteOffset: MemoryLayout<Uniform>.offset(of: \.cameraPosition)!, as: SIMD3<Float>.self)
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.depthAttachment.texture = depthTexture
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setRenderPipelineState(renderPipelineState!)
        renderCommandEncoder.setDepthStencilState(depthStencilState)
        
        renderCommandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: iUniform)
        renderCommandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: iUniform)
        
        axes.draw(renderCommandEncoder)
        rgbTriangle.draw(renderCommandEncoder)
        
        let time = currentFrameTimestamp.timeIntervalSince1970
        square.scaling = SIMD3<Float>(Float(abs(cos(time))), Float(abs(cos(time))), Float(abs(cos(time))))
        square.translation = SIMD3<Float>(Float(cos(time / 2) * sin(time / 3)), Float(cos(time / 3) * cos(time / 2)), Float(sin(time / 2)))
        square.rotation = SIMD3<Float>(Float(time / 4), Float(time / 3), Float(time / 5))
        square.draw(renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit() // implies an enqueue() call
    }
}
