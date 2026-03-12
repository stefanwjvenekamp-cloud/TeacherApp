import Foundation
import SwiftData

enum DataResetService {
    static func clearAll(in context: ModelContext) {
        deleteAll(GradebookSnapshot.self, in: context)
        deleteAll(GradeComment.self, in: context)
        deleteAll(GradeEntry.self, in: context)
        deleteAll(Assessment.self, in: context)
        deleteAll(Student.self, in: context)
        deleteAll(SchoolClass.self, in: context)
        deleteAll(Course.self, in: context)
        deleteAll(Term.self, in: context)
        deleteAll(SchoolYear.self, in: context)
        deleteAll(Subject.self, in: context)
        deleteAll(Teacher.self, in: context)
        removeLegacyJSON()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let descriptor = FetchDescriptor<T>()
        let models = (try? context.fetch(descriptor)) ?? []
        for model in models {
            context.delete(model)
        }
    }

    private static func removeLegacyJSON() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let url = docs?.appendingPathComponent("gradebook_data.json")
        if let url, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
