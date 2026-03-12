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
            GradeComment.self,
            GradebookSnapshot.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            removeDefaultStoreFiles()
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    private static func removeDefaultStoreFiles() {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let url = base.appendingPathComponent("default.store")
        let fileManager = FileManager.default
        let urls = [
            url,
            url.appendingPathExtension("sqlite"),
            url.appendingPathExtension("sqlite-shm"),
            url.appendingPathExtension("sqlite-wal")
        ]
        for target in urls {
            if fileManager.fileExists(atPath: target.path) {
                try? fileManager.removeItem(at: target)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
