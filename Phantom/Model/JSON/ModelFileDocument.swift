//
//  ModelFileDocument.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/26.
//

import UniformTypeIdentifiers
import SwiftUI

struct JSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    static let writableContentTypes: [UTType] = [.json]
    
    var json: String = ""
    
    init() {}
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.json = String(decoding: data, as: UTF8.self)
        } else { self.json = "{}" }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(json.utf8))
    }
}
