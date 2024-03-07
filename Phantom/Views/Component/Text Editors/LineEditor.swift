//
//  LineEditor.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/11/29.
//

import SwiftUI

struct LineEditor: View {
    @Binding var text: String
    @Binding var editable: Bool
    @State private var editing: Bool = false
    @FocusState private var editorFocused: Bool
    
    var body: some View {
        HStack {
            if !editing {
                Text(text).lineLimit(1).onTapGesture(count: 2, perform: {
                    editing = true
                    editorFocused = true
                })
            } else {
                TextField(text: $text) {
                    Text("Text")
                }.focused($editorFocused)
                    .onSubmit { editing = false }
                Button { editing = false } label: {
                    Image(systemName: "checkmark").colorMultiply(.cyan)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        LineEditor(text: .constant("You miling qui"),
                   editable: .constant(true))
        LineEditor(text: .constant("Date"),
                   editable: .constant(true))
    }.frame(width: 300)
}
