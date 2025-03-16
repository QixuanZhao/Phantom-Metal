//
//  AssetCollection.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/2.
//

import Foundation
import Metal

typealias DrawableCollection = AssetCollection<DrawableBase>
typealias TextureCollection = AssetCollection<MTLTexture>
typealias MaterialCollection = AssetCollection<MaterialWrapper>

@MainActor
@Observable
class AssetCollection<T> {
    private(set) var collection: [String: T] = [:]
    
    subscript (name: String?) -> T? { if let name { collection[name] } else { nil } }
    
    var count: Int { collection.count }
    var keys: [String] { collection.keys.sorted(by: <) }
    
    func contains(key: String) -> Bool { collection.contains { key == $0.key } }
    func uniqueName(name: String) -> String {
        if (!contains(key: name)) { return name }
        var i = 1
        var result: String
        repeat {
            result = "\(name) (\(i))"
            i = i + 1
        } while contains(key: result)
        return result
    }
    func get(key: String) -> T? { collection[key] }
    func set(key: String, value: T) { collection[key] = value }
    
    @discardableResult
    func remove(key: String) -> T? { collection.removeValue(forKey: key) }
    
    @discardableResult
    func insert(key: String, value: T) -> Bool {
        if contains(key: key) { return false }
        collection[key] = value
        return true
    }
}

