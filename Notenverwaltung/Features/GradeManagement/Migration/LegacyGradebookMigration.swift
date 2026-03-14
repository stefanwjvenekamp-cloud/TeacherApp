import Foundation
import SwiftData

enum LegacyGradebookMigration {
    @MainActor
    static func migrateIfNeeded(in context: ModelContext) -> Bool {
        false
    }
}

struct SavedClassData: Codable {
    let id: UUID
    let name: String
    let subject: String
    let schoolYear: String
}

struct AppGradebookStore: Codable {
    var classes: [SavedClassData]
    var gradebooks: [UUID: ClassGradebooksState]

    private enum CodingKeys: String, CodingKey {
        case classes, gradebookEntries
    }

    private struct GradebookEntry: Codable {
        let key: UUID
        let value: ClassGradebooksState
    }

    private struct LegacyGradebookEntry: Codable {
        let key: UUID
        let value: ClassGradebookState
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(classes, forKey: .classes)
        let entries = gradebooks.map { GradebookEntry(key: $0.key, value: $0.value) }
        try container.encode(entries, forKey: .gradebookEntries)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classes = try container.decode([SavedClassData].self, forKey: .classes)

        if let entries = try? container.decode([GradebookEntry].self, forKey: .gradebookEntries) {
            gradebooks = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value) })
            return
        }

        let legacyEntries = try container.decode([LegacyGradebookEntry].self, forKey: .gradebookEntries)
        let schoolYearByClassID = Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0.schoolYear) })
        gradebooks = Dictionary(uniqueKeysWithValues: legacyEntries.map { entry in
            let schoolYear = schoolYearByClassID[entry.key] ?? "Schuljahr"
            let tab = GradebookTabState(schoolYear: schoolYear, gradebook: entry.value)
            return (entry.key, ClassGradebooksState(tabs: [tab], selectedTabID: tab.id))
        })
    }

    init(classes: [SavedClassData], gradebooks: [UUID: ClassGradebooksState]) {
        self.classes = classes
        self.gradebooks = gradebooks
    }
}
