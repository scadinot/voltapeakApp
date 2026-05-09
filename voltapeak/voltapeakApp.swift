//
//  voltapeakApp.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import SwiftUI

@main
struct voltapeakApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Pas de nouveau document
            }
            
            CommandMenu("Analyse") {
                Button("Ouvrir un fichier SWV...") {
                    // Géré dans ContentView
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Divider()
                
                Button("Exporter en CSV...") {
                    // Géré dans ContentView
                }
                .keyboardShortcut("e", modifiers: [.command])
            }
        }
    }
}

