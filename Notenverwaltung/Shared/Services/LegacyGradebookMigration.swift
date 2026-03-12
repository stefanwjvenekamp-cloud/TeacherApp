import Foundation
import SwiftData

enum LegacyGradebookMigration {
    @MainActor
    static func migrateIfNeeded(in context: ModelContext) -> Bool {
        guard let legacyStore = loadLegacyStore() else { return false }
        if legacyStore.classes.isEmpty { return false }

        var classMap: [UUID: SchoolClass] = [:]
        for saved in legacyStore.classes {
            let schoolClass = SchoolClass(name: saved.name, subject: saved.subject, schoolYear: saved.schoolYear)
            schoolClass.id = saved.id
            context.insert(schoolClass)
            classMap[saved.id] = schoolClass
        }

        for (classId, state) in legacyStore.gradebooks {
            guard let schoolClass = classMap[classId] else { continue }

            let allRows = state.tabs.flatMap(\.gradebook.rows)
            let uniqueRows = Dictionary(uniqueKeysWithValues: allRows.map { ($0.id, $0) }).values
                .sorted { $0.studentName.localizedStandardCompare($1.studentName) == .orderedAscending }

            for (index, row) in uniqueRows.enumerated() {
                let (firstName, lastName) = splitName(row.studentName)
                let student = Student(
                    firstName: firstName,
                    lastName: lastName,
                    studentNumber: index + 1,
                    classId: classId
                )
                student.id = row.id
                schoolClass.students.append(student)
            }

            GradebookRepository.bootstrapTabsIfNeeded(for: schoolClass, state: state, in: context)
            let tabsByID = Dictionary(uniqueKeysWithValues: GradebookRepository.tabs(for: schoolClass).map { ($0.id, $0) })
            for tabState in state.tabs {
                guard let tab = tabsByID[tabState.id] else { continue }
                GradebookRepository.bootstrapNodesIfNeeded(for: tab, root: tabState.gradebook.root, in: context)
                GradebookRepository.bootstrapRowsIfNeeded(for: tab, state: tabState.gradebook, schoolClass: schoolClass, in: context)
                GradebookRepository.bootstrapCellValuesIfNeeded(for: tab, state: tabState.gradebook, in: context)
            }
        }

        try? context.save()
        deleteLegacyFile()
        return true
    }

    private static func loadLegacyStore() -> AppGradebookStore? {
        guard FileManager.default.fileExists(atPath: legacyFileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: legacyFileURL)
            return try JSONDecoder().decode(AppGradebookStore.self, from: data)
        } catch {
            return nil
        }
    }

    private static var legacyFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("gradebook_data.json")
    }

    private static func deleteLegacyFile() {
        try? FileManager.default.removeItem(at: legacyFileURL)
    }

    private static func splitName(_ fullName: String) -> (String, String) {
        let parts = fullName.split(separator: " ").map(String.init)
        guard let first = parts.first else { return ("", "") }
        let last = parts.dropFirst().joined(separator: " ")
        return (first, last)
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
