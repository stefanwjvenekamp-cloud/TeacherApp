import SwiftUI

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
