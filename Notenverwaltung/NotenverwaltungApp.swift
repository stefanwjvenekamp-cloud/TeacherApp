//
//  NotenverwaltungApp.swift
//  Notenverwaltung
//
//  Created by Stefan Venekamp on 08.03.26.
//

import SwiftUI
import SwiftData

@main
struct NotenverwaltungApp: App {
    var body: some Scene {
        WindowGroup {
            MigrationGateView {
                ContentView()
            }
        }
        .modelContainer(PersistenceController.sharedModelContainer)
    }
}
