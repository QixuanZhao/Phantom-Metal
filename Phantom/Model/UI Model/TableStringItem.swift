//
//  TableStringItem.swift
//  Phantom
//
//  Created by TSAR Weasley on 2024/2/29.
//

struct TableStringItem: Identifiable {
    var id: String { name }
    var name: String
}

struct IndexedTableStringItem: Identifiable {
    var id: Int
    var name: String
}
