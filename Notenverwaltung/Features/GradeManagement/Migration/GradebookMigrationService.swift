import SwiftData

enum GradebookMigrationService {
    @discardableResult
    @MainActor
    static func migrateIfNeeded(context: ModelContext) -> Bool {
        false
    }
}
