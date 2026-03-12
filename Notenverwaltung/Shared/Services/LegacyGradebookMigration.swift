import Foundation
import SwiftData

enum LegacyGradebookMigration {
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

            for (index, row) in state.tabs.first?.gradebook.rows.enumerated() ?? [].enumerated() {
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

            for tab in state.tabs {
                let inputIDs = Set(GradeTileTree.columns(from: tab.gradebook.root).filter { $0.type == .input }.map { $0.nodeID })
                for row in tab.gradebook.rows {
                    for inputID in inputIDs {
                        let raw = row.inputValues[inputID] ?? ""
                        let entry = GradeEntry(
                            studentId: row.id,
                            semesterId: tab.schoolYear,
                            categoryKey: inputID.uuidString,
                            rawValue: raw,
                            value: parsedNumericValue(from: raw)
                        )
                        context.insert(entry)
                    }
                }
            }

            GradebookSnapshotStore.save(state: state, for: classId, in: context)
        }

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

    private static func parsedNumericValue(from rawValue: String) -> Double? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), (1...6).contains(value) else { return nil }
        return value
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
