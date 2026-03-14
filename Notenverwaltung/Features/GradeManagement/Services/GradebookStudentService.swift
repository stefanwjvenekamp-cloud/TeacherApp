import Foundation
import SwiftData

@MainActor
enum GradebookStudentService {

    /// Add a single student by name. Returns the created Student, or nil if the name is empty.
    @discardableResult
    static func addStudent(
        named name: String,
        schoolClass: SchoolClass,
        tab: GradebookTabEntity,
        inputNodeIDs: Set<UUID>,
        context: ModelContext
    ) -> Student? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let nextNumber = (schoolClass.enrollments.compactMap(\.studentNumber).max() ?? 0) + 1
        let (firstName, lastName) = splitName(trimmed)
        let student = Student(firstName: firstName, lastName: lastName)
        context.insert(student)
        let enrollment = GradebookRepository.enrollment(
            for: student,
            studentNumber: nextNumber,
            in: schoolClass,
            context: context
        )
        GradebookRepository.appendRows(for: enrollment, in: schoolClass, context: context)
        GradebookRepository.ensureCellValues(
            for: tab,
            rowIDs: [student.id],
            nodeIDs: inputNodeIDs,
            context: context
        )
        try? context.save()
        return student
    }

    /// Add multiple students by name. Returns the created Students.
    static func addStudents(
        names: [String],
        schoolClass: SchoolClass,
        tab: GradebookTabEntity,
        inputNodeIDs: Set<UUID>,
        context: ModelContext
    ) -> [Student] {
        var nextNumber = (schoolClass.enrollments.compactMap(\.studentNumber).max() ?? 0) + 1
        var created: [Student] = []

        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let (firstName, lastName) = splitName(trimmed)
            let student = Student(firstName: firstName, lastName: lastName)
            context.insert(student)
            let assignedNumber = nextNumber
            nextNumber += 1
            let enrollment = GradebookRepository.enrollment(
                for: student,
                studentNumber: assignedNumber,
                in: schoolClass,
                context: context
            )
            GradebookRepository.appendRows(for: enrollment, in: schoolClass, context: context)
            GradebookRepository.ensureCellValues(
                for: tab,
                rowIDs: [student.id],
                nodeIDs: inputNodeIDs,
                context: context
            )
            created.append(student)
        }
        try? context.save()
        return created
    }

    /// Delete a student by ID.
    static func deleteStudent(
        id: UUID,
        schoolClass: SchoolClass,
        context: ModelContext
    ) {
        GradebookRepository.deleteRows(for: id, in: schoolClass, context: context)

        let descriptor = FetchDescriptor<Student>(predicate: #Predicate { $0.id == id })
        if let student = (try? context.fetch(descriptor))?.first {
            let enrollmentsToDelete = student.classEnrollments.filter { $0.schoolClass?.id == schoolClass.id }
            let hasOtherEnrollments = student.classEnrollments.contains { enrollment in
                enrollment.schoolClass?.id != schoolClass.id
            }

            for enrollment in enrollmentsToDelete {
                context.delete(enrollment)
            }

            if !hasOtherEnrollments {
                context.delete(student)
            }
        }
        try? context.save()
    }

    /// Rename a student's full name.
    static func renameStudent(
        studentID: UUID,
        fullName: String,
        context: ModelContext
    ) {
        let descriptor = FetchDescriptor<Student>(predicate: #Predicate { $0.id == studentID })
        guard let student = (try? context.fetch(descriptor))?.first else { return }
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let (firstName, lastName) = splitName(trimmed)
        student.firstName = firstName
        student.lastName = lastName
        try? context.save()
    }

    /// Split a full name into (firstName, lastName).
    static func splitName(_ fullName: String) -> (String, String) {
        let parts = fullName.split(separator: " ").map(String.init)
        guard let first = parts.first else { return ("", "") }
        let last = parts.dropFirst().joined(separator: " ")
        return (first, last)
    }
}
