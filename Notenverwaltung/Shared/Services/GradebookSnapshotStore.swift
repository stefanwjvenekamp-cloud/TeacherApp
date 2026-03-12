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

enum GradebookSnapshotStore {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load(for classId: UUID, in context: ModelContext) -> ClassGradebooksState? {
        let descriptor = FetchDescriptor<GradebookSnapshot>(
            predicate: #Predicate { $0.classId == classId }
        )
        guard let snapshot = (try? context.fetch(descriptor))?.first else { return nil }
        return try? decoder.decode(ClassGradebooksState.self, from: snapshot.data)
    }

    static func save(state: ClassGradebooksState, for classId: UUID, in context: ModelContext) {
        guard let data = try? encoder.encode(state) else { return }

        let descriptor = FetchDescriptor<GradebookSnapshot>(
            predicate: #Predicate { $0.classId == classId }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.data = data
            existing.updatedAt = Date()
        } else {
            let snapshot = GradebookSnapshot(classId: classId, data: data)
            context.insert(snapshot)
        }
    }
}
