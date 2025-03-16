//
//  SceneNode.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/23.
//

import Foundation
import simd
import Metal
import SwiftUI

infix operator +=
infix operator -=

@MainActor
@Observable
class SceneNode: @preconcurrency Equatable, @preconcurrency Comparable, @preconcurrency Hashable, Identifiable {
    static func < (lhs: SceneNode, rhs: SceneNode) -> Bool { lhs.name < rhs.name }
    static func == (lhs: SceneNode, rhs: SceneNode) -> Bool { lhs.id == rhs.id }
    static func == (lhs: SceneNode, rhs: UUID) -> Bool { lhs.id == rhs }
    static func == (lhs: UUID, rhs: SceneNode) -> Bool { rhs == lhs }
    static func += (lhs: SceneNode, rhs: SceneNode) { lhs.insertChild(rhs) }
    static func += (lhs: SceneNode, rhs: [SceneNode]) { lhs.insertChildren(rhs) }
    static func -= (lhs: SceneNode, rhs: SceneNode) { lhs.removeChild(rhs) }
    static func -= (lhs: SceneNode, rhs: UUID) { lhs.removeChild(rhs) }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    subscript (id: UUID) -> SceneNode? { children[id] }
//    subscript (name: String) -> Set<SceneNode> { children.filter { $0.name == name } }
    
    let id: UUID
    var name: String
    weak var drawable: DrawableBase? // content geometry
    weak var material: MaterialWrapper? // content material
    var visible: Bool = true
    var showAxes: Bool = false
    var fillTriangles: Bool = true
    
    var translation: SIMD3<Float> = .zero { didSet { requireUpdate = true }}
    var rotation: simd_quatf = .init(real: 1, imag: .zero) { didSet { requireUpdate = true }}
    var scaling: SIMD3<Float> = .one { didSet { requireUpdate = true }}
    
    private var modelBuffer: MTLBuffer?
    private(set) var model: simd_float4x4 = simd_float4x4(diagonal: .one)
    private var requireUpdate = true
    
    private(set) var children: Dictionary<UUID, SceneNode> = [:]
    private(set) unowned var parent: SceneNode?
    
    var childrenArray: [SceneNode] { children.values.sorted(by: < ) }
    
    @discardableResult
    func updateModel() -> Bool {
        if !requireUpdate { return false }
        requireUpdate = false
        let scale = simd_float4x4(diagonal: SIMD4<Float>(scaling, 1))
        let rotX = rotation.act(SIMD3<Float>(1, 0, 0))
        let rotY = rotation.act(SIMD3<Float>(0, 1, 0))
        let rotZ = rotation.act(SIMD3<Float>(0, 0, 1))
        let rotate = simd_float4x4(
            SIMD4<Float>(rotX, 0),
            SIMD4<Float>(rotY, 0),
            SIMD4<Float>(rotZ, 0),
            SIMD4<Float>(.zero, 1)
        )
        var translate = simd_float4x4(diagonal: .one)
        translate[3] = SIMD4<Float>(translation, 1)
        
        model = translate * rotate * scale
        return true
    }
    
    init(id: UUID = UUID(), 
         name: String = "New Object",
         parent: SceneNode? = nil,
         drawable: DrawableBase? = nil,
         children: [SceneNode] = []) {
        self.id = id
        self.name = name
        self.parent = parent
        self.drawable = drawable
        insertChildren(children)
        self.modelBuffer = MetalSystem.shared.device.makeBuffer(length: MemoryLayout<simd_float4x4>.size)
    }
    
    func draw(parentModel: simd_float4x4 = .init(diagonal: .one),
              encoder: MTLRenderCommandEncoder) {
        updateModel()
        let currentModel = parentModel * model
        
        if visible || showAxes {
            modelBuffer?.contents().storeBytes(of: currentModel, as: simd_float4x4.self)
            encoder.setVertexBuffer(modelBuffer, offset: 0, index: BufferPosition.model.rawValue)
            encoder.setTriangleFillMode(fillTriangles ? .fill : .lines)
            if visible, let drawable {
                if let material { material.set(encoder) } else { MaterialWrapper.default.set(encoder) }
                drawable.draw(encoder, instanceCount: 1, baseInstance: 0)
            }
            
            if showAxes {
                Axes.draw(encoder, instanceCount: 1, baseInstance: 0)
            }
        }
        
        if visible {
            for (_, child) in children { child.draw(parentModel: currentModel, encoder: encoder) }
        }
    }
    
    func drawAxes(parentModel: simd_float4x4 = .init(diagonal: .one),
                  encoder: MTLRenderCommandEncoder) {
        updateModel()
        let currentModel = parentModel * model

        if showAxes {
            modelBuffer?.contents().storeBytes(of: currentModel, as: simd_float4x4.self)
            encoder.setVertexBuffer(modelBuffer, offset: 0, index: BufferPosition.model.rawValue)
            
            Axes.draw(encoder, instanceCount: 1, baseInstance: 0)
        }
        
        for (_, child) in children { child.drawAxes(parentModel: currentModel, encoder: encoder) }
    }
    
    func insertChild(_ child: SceneNode) {
        let replacedChild = children.updateValue(child, forKey: child.id)
        child.parent = self
        replacedChild?.parent = nil
    }
    
    func insertChildren(_ children: [SceneNode]) { for child in children { insertChild(child) } }
    
    func removeChild(_ child: SceneNode) { children.removeValue(forKey: child.id)?.parent = nil }
    func removeChild(_ childID: UUID) { children.removeValue(forKey: childID)?.parent = nil }
    func removeChildren(_ children: [SceneNode]) { for child in children { removeChild(child) } }
    func removeChildren(_ children: [UUID]) { for child in children { removeChild(child) } }
    
    func applyToDirectChildren(predicate: (SceneNode) -> Void) {
        for (_, child) in children { predicate(child) }
    }
    
    func applyToDirectChildren(predicate: (SceneNode) -> Int,
                               integerOperator op: (Int, Int) -> Int = { $0 + $1 },
                               initialIntergerValue: Int = 0) -> Int {
        var count = initialIntergerValue
        for (_, child) in children { count = op(count, predicate(child)) }
        return count
    }
    
    func applyToDirectChildren(predicate: (SceneNode) -> Bool,
                               booleanOperator op: (Bool, Bool) -> Bool = { $0 && $1 },
                               initialBooleanValue: Bool = true) -> Bool {
        var success = true
        for (_, child) in children { success = op(predicate(child), success) }
        return success
    }
    
    func apply(predicate: (SceneNode) -> Void) {
        predicate(self)
        for (_, child) in children { child.apply(predicate: predicate) }
    }
    
    func apply(predicate: (SceneNode) -> Int) -> Int {
        var count = predicate(self)
        for (_, child) in children { count = count + child.apply(predicate: predicate) }
        return count
    }
    
    func apply(predicate: (SceneNode) -> Bool) -> Bool {
        var success = predicate(self)
        for (_, child) in children { success = child.apply(predicate: predicate) && success }
        return success
    }
}
