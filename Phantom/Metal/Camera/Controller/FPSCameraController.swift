//
//  FPSCameraController.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/16.
//

import simd
import SwiftUI

class FPSCameraController: CameraController {
    
    enum Direction {
        case forward, backward, left, right, up, down, unknown
        
        static func map(_ char: Character) -> Direction {
            return switch char {
            case "w": .forward
            case "s": .backward
            case "a": .left
            case "d": .right
            case "e": .up
            case "q": .down
            default: .unknown
            }
        }
    }
    
    unowned var camera: Camera?
    
    var cursor: CGPoint = .zero
    var sensitivity: Float = 1.0
    var velocity: Float = 1.0
    private var firstPoll = true
    var viewLock = true
    var motionLock = false
    
    var movingDirections: Set<Direction> = []
    
    init(camera: Camera? = nil) {
        self.camera = camera
    }
    
    private func resolveCursor() {
        if firstPoll {
            firstPoll = false
            cursor = NSEvent.mouseLocation
            return
        }
        
        let currentCursorLocation = NSEvent.mouseLocation
        if !viewLock, let camera {
            let dx = (currentCursorLocation.x - cursor.x) / 10.0
            let dy = (currentCursorLocation.y - cursor.y) / 10.0
            
            camera.yaw = camera.yaw - sensitivity * Float(dx)
            camera.pitch = camera.pitch + sensitivity * Float(dy)
        }
        cursor = currentCursorLocation
    }
    
    private func resolveKeyboard(_ deltaT: Float) {
        if !motionLock, let camera {
            var offset: SIMD3<Float> = .zero
            for direction in movingDirections {
                switch direction {
                case .forward: offset = offset + camera.front
                case .backward: offset = offset - camera.front
                case .left: offset = offset - camera.right
                case .right: offset = offset + camera.right
                case .up: offset = offset + camera.up
                case .down: offset = offset - camera.up
                default: break
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
