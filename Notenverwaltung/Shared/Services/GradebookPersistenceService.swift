import Foundation

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

enum GradebookPersistence {
    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("gradebook_data.json")
    }

    static func save(classes: [SchoolClass], gradebooks: [UUID: ClassGradebooksState]) {
        let savedClasses = classes.map {
            SavedClassData(id: $0.id, name: $0.name, subject: $0.subject, schoolYear: $0.schoolYear)
        }
        let store = AppGradebookStore(classes: savedClasses, gradebooks: gradebooks)

        do {
            let data = try JSONEncoder().encode(store)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }

    static func load() -> (classes: [SchoolClass], gradebooks: [UUID: ClassGradebooksState])? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let store = try JSONDecoder().decode(AppGradebookStore.self, from: data)

            let classes = store.classes.map { saved -> SchoolClass in
                let sc = SchoolClass(name: saved.name, subject: saved.subject, schoolYear: saved.schoolYear)
                sc.id = saved.id
                return sc
            }

            return (classes, store.gradebooks)
        } catch {
            print("Fehler beim Laden: \(error)")
            return nil
        }
    }
}
