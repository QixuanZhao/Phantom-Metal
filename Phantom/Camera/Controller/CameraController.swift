//
//  CameraController.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/16.
//

import simd

protocol CameraController {
    var camera: Camera { get set }
    func update(_ deltaT: Float)
}
