import Foundation
import SwiftData

@MainActor
enum MockSeedDataService {

    /// Seed the database with sample classes and students if no classes exist.
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<SchoolClass>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let existingClasses = (try? context.fetch(descriptor)) ?? []
        guard existingClasses.isEmpty else { return }

        let classConfigs: [(name: String, subject: String, year: String, students: [String])] = [
            ("10b", "Deutsch", "2025/2026", [
                "Anna Müller", "Ben Schmidt", "Clara Weber", "David Fischer",
                "Emilia Wagner", "Felix Neumann", "Greta Hoffmann", "Henry Becker"
            ]),
            ("5a", "Mathematik", "2025/2026", [
                "Lina Koch", "Noah Richter", "Mia Wolf",
                "Paul Krüger", "Sofia Hartmann", "Tom Schulz"
            ])
        ]

        for config in classConfigs {
            let schoolClass = SchoolClass(name: config.name, subject: config.subject, schoolYear: config.year)
            context.insert(schoolClass)

            // Create students
            for (index, fullName) in config.students.enumerated() {
                let (firstName, lastName) = GradebookStudentService.splitName(fullName)
                let student = Student(
                    firstName: firstName,
                    lastName: lastName,
                    studentNumber: index + 1,
                    classId: schoolClass.id
                )
                schoolClass.students.append(student)
            }

            // Create default tab with standard tree
            let tab = GradebookTabEntity(
                title: config.year,
                sortOrder: 0,
                roundingDecimals: 2,
                schoolClass: schoolClass
            )
            context.insert(tab)

            // Create node tree
            let root = GradeTileTree.standardRoot()
            let rootEntity = GradebookTreeService.makeEntityTree(from: root, tab: tab)
            context.insert(rootEntity)

            // Create rows for each student
            for student in schoolClass.students {
                let row = GradebookRowEntity(
                    id: student.id,
                    sortOrder: student.studentNumber - 1,
                    tab: tab,
                    student: student
                )
                context.insert(row)
            }
        }

        try? context.save()
    }
}
