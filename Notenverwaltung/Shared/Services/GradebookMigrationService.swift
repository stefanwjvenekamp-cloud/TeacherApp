import Foundation
import SwiftData

// MARK: - Legacy Types (for migration only)

private struct SavedClassData: Codable {
    let id: UUID
    let name: String
    let subject: String
    let schoolYear: String
}

private struct AppGradebookStore: Codable {
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
}

// MARK: - Migration Service

enum GradebookMigrationService {

    private static var legacyFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("gradebook_data.json")
    }

    /// Migrates legacy JSON gradebook data into SwiftData. Returns true if migration was performed.
    @discardableResult
    static func migrateIfNeeded(context: ModelContext) -> Bool {
        let fileURL = legacyFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let store = try JSONDecoder().decode(AppGradebookStore.self, from: data)

            for savedClass in store.classes {
                let schoolClass = SchoolClass(
                    name: savedClass.name,
                    subject: savedClass.subject,
                    schoolYear: savedClass.schoolYear
                )
                schoolClass.id = savedClass.id

                if let gradebooksState = store.gradebooks[savedClass.id] {
                    schoolClass.encodeGradebooksState(gradebooksState)
                }

                context.insert(schoolClass)
            }

            try context.save()
            try FileManager.default.removeItem(at: fileURL)

            print("[Migration] Successfully migrated \(store.classes.count) classes from JSON to SwiftData.")
            return true
        } catch {
            print("[Migration] Failed: \(error)")
            return false
        }
    }
}
