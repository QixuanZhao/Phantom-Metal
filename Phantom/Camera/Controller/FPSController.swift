//
//  FPSController.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/16.
//

import simd
import SwiftUI

class FPSController: CameraController {
    
    enum Direction: Character {
        case forward  = "w"
        case backward = "s"
        case left     = "a"
        case right    = "d"
        case up       = "e"
        case down     = "q"
    }
    
    unowned var camera: Camera
    
    private var firstPoll = true
    private(set) var cursor: CGPoint = .zero
    var sensitivity: Float = 1.0
    var velocity: Float = 50
    var viewLock = true
    var motionLock = false
    
    var movingDirections: Set<Direction> = []
    
    init(camera: Camera) { self.camera = camera }
    func control(camera: Camera) { self.camera = camera }
    
    private func resolveCursor() {
        if firstPoll {
            firstPoll = false
            cursor = NSEvent.mouseLocation
            return
        }
        
        let currentCursorLocation = NSEvent.mouseLocation
        if !viewLock {
            let dx = (currentCursorLocation.x - cursor.x) / 10.0
            let dy = (currentCursorLocation.y - cursor.y) / 10.0
            
            camera.yaw = camera.yaw - sensitivity * Float(dx)
            camera.pitch = camera.pitch + sensitivity * Float(dy)
        }
        cursor = currentCursorLocation
    }
    
    private func resolveKeyboard(_ deltaT: Float) {
        if !motionLock {
            var offset: SIMD3<Float> = .zero
            for direction in movingDirections {
                switch direction {
                case .forward:  offset = offset + camera.front
                case .backward: offset = offset - camera.front
                case .left:     offset = offset - camera.right
                case .right:    offset = offset + camera.right
                case .up:       offset = offset + camera.up
                case .down:     offset = offset - camera.up
                }
            }
            let norm = length(offset)
            if norm > 0 { offset = offset / norm }
            
            camera.position = camera.position + deltaT * velocity * offset
        }
    }
    
    func update(_ deltaT: Float) {
        resolveCursor()
        resolveKeyboard(deltaT)
    }
}
