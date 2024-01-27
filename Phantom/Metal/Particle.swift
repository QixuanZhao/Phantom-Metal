//
//  Particle.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/21.
//

import Foundation

struct Particle: Codable {
    let num:      Int
    let x:        Float
    let y:        Float
    let z:        Float
    let state:    Float
    let pressure: Float
    let density:  Float
    
    static func load(filename: String) throws -> [Particle]? {
        if let json = try? String(contentsOfFile: filename) {
            return try parse(json: json)
        } else { return nil }
    }
    
    static func parse(json: String) throws -> [Particle]? {
        let decoder = JSONDecoder()
        return try decoder.decode([Particle].self, from: json.data(using: .utf8)!)
    }
}

class Pool {
    var particles: [Particle] = []
    
    init(json: String) throws {
        if let particles = try Particle.parse(json: json) {
            self.particles = particles
        }
    }
    
    init(filename: String) throws {
        if let particles = try Particle.load(filename: filename) {
            self.particles = particles
        }
    }
}
