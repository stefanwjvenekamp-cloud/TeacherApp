import Foundation
import SwiftData

@Model
final class GradebookSnapshot {
    var id: UUID
    var classId: UUID
    var data: Data
    var updatedAt: Date

    init(classId: UUID, data: Data, updatedAt: Date = Date()) {
        self.id = UUID()
        self.classId = classId
        self.data = data
        self.updatedAt = updatedAt
    }
}

/// Utilities for reading legacy snapshot data during migration.
enum GradebookSnapshotStore {
    private static let decoder = JSONDecoder()

    static func decodeState(from data: Data) -> ClassGradebooksState? {
        try? decoder.decode(ClassGradebooksState.self, from: data)
    }
}
