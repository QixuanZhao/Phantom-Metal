//
//  MaterialWrapper.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/5.
//

import Foundation
import Metal

class MaterialWrapper: Identifiable, Equatable {
    static func == (lhs: MaterialWrapper, rhs: MaterialWrapper) -> Bool { lhs.id == rhs.id }
    
    var id: String = "Material"
    var material: Material {
        didSet { requireStore = true }
    }
    
    var albedo: SIMD3<Float> {
        get { [material.albedoSpecular.x, material.albedoSpecular.y, material.albedoSpecular.z] }
        set {
            material.albedoSpecular.x = newValue.x
            material.albedoSpecular.y = newValue.y
            material.albedoSpecular.z = newValue.z
        }
    }
    
    var specular: Float {
        get { material.albedoSpecular.w }
        set { material.albedoSpecular.w = newValue }
    }
    
    var refractiveIndices: SIMD3<Float> {
        get { [material.refractiveIndicesRoughnessU.x, material.refractiveIndicesRoughnessU.y, material.refractiveIndicesRoughnessU.z] }
        set {
            material.refractiveIndicesRoughnessU.x = newValue.x
            material.refractiveIndicesRoughnessU.y = newValue.y
            material.refractiveIndicesRoughnessU.z = newValue.z
        }
    }
    
    var extinctionCoefficients: SIMD3<Float> {
        get { [material.extinctionCoefficentsRoughnessV.x, material.extinctionCoefficentsRoughnessV.y, material.extinctionCoefficentsRoughnessV.z] }
        set {
            material.extinctionCoefficentsRoughnessV.x = newValue.x
            material.extinctionCoefficentsRoughnessV.y = newValue.y
            material.extinctionCoefficentsRoughnessV.z = newValue.z
        }
    }
    
    var roughness: SIMD2<Float> {
        get { [material.refractiveIndicesRoughnessU.w, material.extinctionCoefficentsRoughnessV.w] }
        set {
            material.refractiveIndicesRoughnessU.w = newValue.x
            material.extinctionCoefficentsRoughnessV.w = newValue.y
        }
    }
    
    private var requireStore = true
    private var materialBuffer: MTLBuffer?
    
    init(material: Material) {
        self.material = material
        self.materialBuffer = system.device.makeBuffer(length: MemoryLayout<Material>.size)
        self.materialBuffer?.contents().storeBytes(of: material, as: Material.self)
    }
    
    convenience init(albedo: SIMD3<Float>,
         specular: Float,
         roughness: SIMD2<Float>,
         refractiveIndices: SIMD3<Float>,
         extinctionCoefficents: SIMD3<Float>) {
        self.init(material: Material (
            albedoSpecular: SIMD4<Float>(albedo, specular),
            refractiveIndicesRoughnessU: SIMD4<Float>(refractiveIndices, roughness.x),
            extinctionCoefficentsRoughnessV: SIMD4<Float>(extinctionCoefficents, roughness.y)
        ))
    }
    
    func set(_ encoder: MTLRenderCommandEncoder) {
        if requireStore {
            self.materialBuffer?.contents().storeBytes(of: material, as: Material.self).self
            requireStore = false
        }
        encoder.setFragmentBuffer(materialBuffer, offset: 0, index: BufferPosition.material.rawValue)
    }
}
