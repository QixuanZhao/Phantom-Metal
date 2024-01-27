////
////  Liquid.swift
////  Phantom
////
////  Created by TSAR Weasley on 2023/11/21.
////
//
//import simd
//import Metal
//
//class Liquid: TransformableGeometry, Drawable {
//    private var pointSet: PointSet
//    private var sphere: Sphere
//    private var pool: Pool
//    private var models: [simd_float4x4]
//    private var modelBuffer: MTLBuffer?
//    
//    init(_ device: MTLDevice?, pool: Pool) {
//        self.pool = pool
//        let particles = pool.particles.filter { $0.state == 1.0 }
//        self.pointSet = PointSet(device, particles.map { particle in
//            let position = SIMD3<Float>(particle.x, particle.y, particle.z)
//            return Vertex(position: position, color: .one)
//        })
//        
//        models = particles.map { particle in
//            let position = SIMD3<Float>(particle.x, particle.y, particle.z)
//            let temp = Transformable()
//            temp.translation = position
//            temp.scaling = .one * 0.01
//            _ = temp.updateModel()
//            return temp.model
//        }
//        
//        modelBuffer = device?.makeBuffer(bytes: models, length: models.count * MemoryLayout<simd_float4x4>.stride)
//        
//        self.sphere = Sphere(device)
//        super.init(device)
//    }
//    
//    func draw(_ encoder: MTLRenderCommandEncoder) {
////        setModelBuffer(encoder)
//        encoder.setVertexBuffer(modelBuffer, offset: 0, index: VertexBufferPosition.model.rawValue)
//        sphere.draw(encoder, models.count)
//        
////        spheres[0].draw(encoder, spheres.count)
////        for sphere in spheres {
////            sphere.draw(encoder)
////        }
////        encoder.setVertexBytes([Vertex(position: .zero, color: .one)], length: MemoryLayout<Vertex>.size, index: VertexBufferPosition.vertex.rawValue)
//
////        pointSet.draw(encoder)
//    }
//}
//
