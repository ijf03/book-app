//
//  Book_AppApp.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

@main
struct Book_AppApp: App {
    
    private let container = AppContainer()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container.router)
        }
    }
}
