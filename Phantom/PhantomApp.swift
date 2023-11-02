//
//  PhantomApp.swift
//  Phantom
//
//  Created by TSAR Weasley on 2023/10/11.
//

import SwiftUI

@main
struct PhantomApp: App {
    @StateObject var renderer = Renderer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environmentObject(renderer)
    }
}
