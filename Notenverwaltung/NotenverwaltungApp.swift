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
            GradebookTabEntity.self,
            GradebookNodeEntity.self,
            GradebookRowEntity.self,
            GradebookCellValueEntity.self,
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
            // Schema migration failed — delete the old store and retry
            let storeURL = modelConfiguration.url
            let storeDir = storeURL.deletingLastPathComponent()
            let baseName = storeURL.lastPathComponent  // e.g. "default.store"
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = storeDir.appendingPathComponent(baseName + suffix)
                try? FileManager.default.removeItem(at: fileURL)
            }

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MigrationGateView {
                ContentView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
struct MigrationGateView<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @State private var migrationComplete = false

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if migrationComplete {
                content()
            } else {
                ProgressView("Daten werden vorbereitet…")
                    .task {
                        GradebookMigrationService.migrateIfNeeded(context: modelContext)
                        migrationComplete = true
                    }
            }
        }
    }
}

