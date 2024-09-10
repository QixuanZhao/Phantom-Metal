//
//  TableStringItem.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/29.
//

import SwiftUI

struct TableStringItem: Identifiable, Codable {
    var id: String { name }
    var name: String
}

struct IndexedTableStringItem: Identifiable, Codable, Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
    
    var id: Int
    var name: String
}
