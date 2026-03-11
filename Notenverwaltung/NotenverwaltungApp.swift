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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Teacher.self,
            Subject.self,
            SchoolYear.self,
            Term.self,
            Course.self,
            SchoolClass.self,
            Student.self,
            Assessment.self,
            GradeEntry.self,
            GradeComment.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
