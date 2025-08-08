//
//  Renderer.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/11.
//

import SwiftUI
import MetalKit

@MainActor
@Observable
class Renderer: NSObject, MTKViewDelegate {
    var fps: Double = 0.0
    private(set) var startTimestamp: Date!
    private(set) var lastFrameTimestamp: Date = .now
    var backgroundColor: Color.Resolved?
    var resolution: CGSize = .zero
    var clearColor: MTLClearColor {
        if let backgroundColor {
            MTLClearColorMake(
                Double(backgroundColor.red),
                Double(backgroundColor.green),
                Double(backgroundColor.blue),
                Double(backgroundColor.opacity)
            )
        } else { MTLClearColorMake(1, 1, 1, 1) }
    }
    
    private var depthTexture: MTLTexture
    private var positionTexture: MTLTexture
    private var normalTexture: MTLTexture
    private var albedoSpecularTexture: MTLTexture
    private var refractiveIndicesRoughnessUTexture: MTLTexture
    private var extinctionCoefficentsRoughnessVTexture: MTLTexture
    private var hdrTexture: MTLTexture
    
    private var deferredPipelineState: MTLRenderPipelineState?
    private var postprocessPipelineState: MTLRenderPipelineState?
    private var depthStencilState: MTLDepthStencilState?
    
    private var renderPassDescriptor = MTLRenderPassDescriptor()
    private var postprocessPassDescriptor = MTLRenderPassDescriptor()
    
    private var uniformBuffer: MTLBuffer?
    private var lightBuffer: MTLBuffer?
    private var lightCountBuffer: MTLBuffer?
    
    let postprocessVertexFunction = MetalSystem.shared.library.makeFunction(name: "postprocess::vertexShader")
    let postprocessFragmentFunction = MetalSystem.shared.library.makeFunction(name: "postprocess::fragmentShader")
    let memorylessFragmentFunction = MetalSystem.shared.library.makeFunction(name: "memorylessFS")
    
    var camera: Camera = Camera()
    var controller: FPSController
    
    weak var scene: SceneGraph?
    
    var lights: [Light] = [
        Light(intensity: 1, roughness: 0.1, ambient: 0, direction: [1, -1, 3]),
        Light(intensity: 1, roughness: 0.1, ambient: 0, direction: [-1, -1, -3])
    ] {
        didSet {
            lightBuffer = MetalSystem.shared.device.makeBuffer(bytes: lights, length: MemoryLayout<Light>.size * lights.count, options: .storageModeShared)
        }
    }
    
    var uniform = Uniform(
        view: .init(diagonal: .one),
        projection: .init(diagonal: .one),
        cameraPositionAndFOV: [0, 0, 0, Float.pi / 4],
        planesAndframeSize: [ 1, 100, 1, 1 ],
        pointSizeAndCurvilinearPerspective: SIMD4<Float>(20, 0, 0, 0)
    )
    
//    private var semaphore = DispatchSemaphore(value: 3)
    
    override init () {
        let camera = Camera()
        self.camera = camera
        controller = FPSController(camera: camera)
        
        let deferredRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        deferredRenderPipelineDescriptor.vertexDescriptor = Vertex.descriptor
        deferredRenderPipelineDescriptor.vertexFunction = postprocessVertexFunction
        deferredRenderPipelineDescriptor.fragmentFunction = memorylessFragmentFunction
        deferredRenderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        deferredRenderPipelineDescriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = MetalSystem.shared.hdrTextureDescriptor.pixelFormat
        deferredRenderPipelineDescriptor.colorAttachments[ColorAttachment.position.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        deferredRenderPipelineDescriptor.colorAttachments[ColorAttachment.normal.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        deferredRenderPipelineDescriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        deferredRenderPipelineDescriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        deferredRenderPipelineDescriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].pixelFormat = MetalSystem.shared.geometryTextureDescriptor.pixelFormat
        deferredRenderPipelineDescriptor.label = "Deferred Shading Pipeline State"
        self.deferredPipelineState = try? MetalSystem.shared.device.makeRenderPipelineState(descriptor: deferredRenderPipelineDescriptor)
        
        let postprocessPipelineDescriptor = MTLRenderPipelineDescriptor()
        postprocessPipelineDescriptor.vertexDescriptor = Vertex.descriptor
        postprocessPipelineDescriptor.vertexFunction = postprocessVertexFunction
        postprocessPipelineDescriptor.fragmentFunction = postprocessFragmentFunction
        postprocessPipelineDescriptor.colorAttachments[ColorAttachment.color.rawValue].pixelFormat = .rgba16Float
        postprocessPipelineDescriptor.label = "Post-process Pipeline State"
        self.postprocessPipelineState = try? MetalSystem.shared.device.makeRenderPipelineState(descriptor: postprocessPipelineDescriptor)
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilDescriptor.label = "Depth Stencil State"
        self.depthStencilState = MetalSystem.shared.device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        uniformBuffer = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<Uniform>.size, options: .storageModeShared)
        lightCountBuffer = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<Int32>.size, options: .storageModeShared)
        
        depthTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.depthTextureDescriptor)!
        positionTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        normalTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        albedoSpecularTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        refractiveIndicesRoughnessUTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        extinctionCoefficentsRoughnessVTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        hdrTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.hdrTextureDescriptor)!
        
        super.init()
        
        lightBuffer = MetalSystem.shared.device.makeBuffer(bytes: lights, length: MemoryLayout<Light>.size * lights.count, options: .storageModeShared)
        
        depthTexture.label = "Depth Texture"
        positionTexture.label = "Position Texture"
        normalTexture.label = "Normal Texture"
        albedoSpecularTexture.label = "AlbedoSpecular Texture"
        refractiveIndicesRoughnessUTexture.label = "Refractive Indices & Roughness U Texture"
        extinctionCoefficentsRoughnessVTexture.label = "Extinction Coefficents & Roughness V Texture"
        hdrTexture.label = "HDR Texture"
    }
    
    private func recreateTextures(width: Int, height: Int) {
        MetalSystem.shared.depthTextureDescriptor.width = width
        MetalSystem.shared.depthTextureDescriptor.height = height
        
        MetalSystem.shared.geometryTextureDescriptor.width = width
        MetalSystem.shared.geometryTextureDescriptor.height = height
        
        MetalSystem.shared.hdrTextureDescriptor.width = width
        MetalSystem.shared.hdrTextureDescriptor.height = height
        
        depthTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.depthTextureDescriptor)!
        positionTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        normalTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        albedoSpecularTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        refractiveIndicesRoughnessUTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        extinctionCoefficentsRoughnessVTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.geometryTextureDescriptor)!
        hdrTexture = MetalSystem.shared.device.makeTexture(descriptor: MetalSystem.shared.hdrTextureDescriptor)!
        
        depthTexture.label = "Depth Texture"
        positionTexture.label = "Position Texture"
        normalTexture.label = "Normal Texture"
        albedoSpecularTexture.label = "AlbedoSpecular Texture"
        refractiveIndicesRoughnessUTexture.label = "Refractive Indices & Roughness U Texture"
        extinctionCoefficentsRoughnessVTexture.label = "Extinction Coefficents & Roughness V Texture"
        hdrTexture.label = "HDR Texture"
        
        setupRenderPasses()
        startTimestamp = .now
    }
    
    func setupRenderPasses() {
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.clearDepth = 1
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        renderPassDescriptor.colorAttachments[ColorAttachment.color.rawValue].texture = hdrTexture
        renderPassDescriptor.colorAttachments[ColorAttachment.color.rawValue].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[ColorAttachment.color.rawValue].storeAction = .store
        renderPassDescriptor.colorAttachments[ColorAttachment.position.rawValue].texture = positionTexture
        renderPassDescriptor.colorAttachments[ColorAttachment.position.rawValue].clearColor = MTLClearColorMake(0, 0, 0, 0)
        renderPassDescriptor.colorAttachments[ColorAttachment.position.rawValue].loadAction = .clear
        renderPassDescriptor.colorAttachments[ColorAttachment.position.rawValue].storeAction = .dontCare
        renderPassDescriptor.colorAttachments[ColorAttachment.normal.rawValue].texture = normalTexture
        renderPassDescriptor.colorAttachments[ColorAttachment.normal.rawValue].clearColor = MTLClearColorMake(0, 0, 0, 0)
        renderPassDescriptor.colorAttachments[ColorAttachment.normal.rawValue].loadAction = .clear
        renderPassDescriptor.colorAttachments[ColorAttachment.normal.rawValue].storeAction = .dontCare
        renderPassDescriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].texture = albedoSpecularTexture
        renderPassDescriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].loadAction = .clear
        renderPassDescriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].storeAction = .dontCare
        renderPassDescriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].texture = refractiveIndicesRoughnessUTexture
        renderPassDescriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].loadAction = .clear
        renderPassDescriptor.colorAttachments[ColorAttachment.refractiveRoughness1.rawValue].storeAction = .dontCare
        renderPassDescriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].texture = extinctionCoefficentsRoughnessVTexture
        renderPassDescriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].loadAction = .clear
        renderPassDescriptor.colorAttachments[ColorAttachment.extinctionRoughness2.rawValue].storeAction = .dontCare
        
        postprocessPassDescriptor.colorAttachments[ColorAttachment.color.rawValue].loadAction = .dontCare
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.resolution = size
        camera.aspectRatio = Float(size.width / size.height)
        
        recreateTextures(width: Int(size.width), height: Int(size.height))
    }
    
    func draw(in view: MTKView) {
        let currentFrameTimestamp = Date.now
        let timeInterval = currentFrameTimestamp.timeIntervalSince(lastFrameTimestamp)
        lastFrameTimestamp = currentFrameTimestamp
        
        controller.update(Float(timeInterval))
        
        let drawableWidth = Float(view.drawableSize.width)
        let drawableHeight = Float(view.drawableSize.height)
        guard let drawable = view.currentDrawable else { return }
        postprocessPassDescriptor.colorAttachments[ColorAttachment.color.rawValue].texture = drawable.texture
        renderPassDescriptor.renderTargetWidth = Int(drawableWidth)
        renderPassDescriptor.renderTargetHeight = Int(drawableHeight)
        postprocessPassDescriptor.renderTargetWidth = Int(drawableWidth)
        postprocessPassDescriptor.renderTargetHeight = Int(drawableHeight)
        renderPassDescriptor.colorAttachments[ColorAttachment.color.rawValue].clearColor = clearColor
        renderPassDescriptor.colorAttachments[ColorAttachment.albedoSpecular.rawValue].clearColor = clearColor
        postprocessPassDescriptor.colorAttachments[ColorAttachment.color.rawValue].clearColor = clearColor
        
        uniformBuffer?.contents().storeBytes(of: camera.view, toByteOffset: MemoryLayout<Uniform>.offset(of: \.view)!,
                                             as: simd_float4x4.self)
        uniformBuffer?.contents().storeBytes(of: camera.projection, toByteOffset: MemoryLayout<Uniform>.offset(of: \.projection)!,
                                             as: simd_float4x4.self)
        uniformBuffer?.contents().storeBytes(of: SIMD4<Float>(camera.position, camera.fov * Float.pi / 180),
                                             toByteOffset: MemoryLayout<Uniform>.offset(of: \.cameraPositionAndFOV)!,
                                             as: SIMD4<Float>.self)
        uniformBuffer?.contents().storeBytes(of: [camera.near, camera.far, drawableWidth, drawableHeight],
                                             toByteOffset: MemoryLayout<Uniform>.offset(of: \.planesAndframeSize)!,
                                             as: SIMD4<Float>.self)
        uniformBuffer?.contents().storeBytes(of: uniform.pointSizeAndCurvilinearPerspective,
                                             toByteOffset: MemoryLayout<Uniform>.offset(of: \.pointSizeAndCurvilinearPerspective)!,
                                             as: SIMD4<Float>.self)
        
        lightCountBuffer?.contents().storeBytes(of: Int32(lights.count), as: Int32.self)
        
        guard let commandBuffer = MetalSystem.shared.commandQueue.makeCommandBuffer() else { return }
        commandBuffer.label = "Command Buffer"
                
        guard let renderPassEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        MaterialWrapper.default.set(renderPassEncoder)
        renderPassEncoder.label = "Combined Deferred Render Pass Encoder"
        renderPassEncoder.setDepthStencilState(depthStencilState)
        renderPassEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: BufferPosition.uniform.rawValue)
        scene?.root.draw(encoder: renderPassEncoder)
        
        renderPassEncoder.setTriangleFillMode(.fill)
        renderPassEncoder.setRenderPipelineState(deferredPipelineState!)
        renderPassEncoder.setFragmentBuffer(lightBuffer, offset: 0, index: BufferPosition.light.rawValue)
        renderPassEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: BufferPosition.uniform.rawValue)
        renderPassEncoder.setFragmentBuffer(lightCountBuffer, offset: 0, index: BufferPosition.lightCount.rawValue)
        Quad.draw(renderPassEncoder)
        renderPassEncoder.endEncoding()
        
        guard let postprocessPassEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: postprocessPassDescriptor) else { return }
        postprocessPassEncoder.label = "Post-process Pass Encoder"
        postprocessPassEncoder.setRenderPipelineState(postprocessPipelineState!)
        postprocessPassEncoder.setFragmentTexture(hdrTexture, index: ColorAttachment.color.rawValue)
        postprocessPassEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: BufferPosition.uniform.rawValue)
        Quad.draw(postprocessPassEncoder)
        postprocessPassEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit() // implies an enqueue() call
    }
}
