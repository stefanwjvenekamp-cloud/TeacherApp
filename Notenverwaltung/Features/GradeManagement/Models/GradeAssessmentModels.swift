import Foundation
import SwiftData

enum AssessmentCategory: String, Codable, CaseIterable {
    case written
    case oral
    case practical
    case test
    case project
    case other
}

struct GradeWeighting: Codable, Hashable {
    var percent: Double

    init(percent: Double) {
        self.percent = percent
    }
}

@Model
final class Assessment {
    var id: UUID
    var title: String
    var subjectId: UUID?
    var classId: UUID?
    var courseId: UUID?
    var termId: UUID?
    var date: Date
    var categoryRawValue: String
    var weightingPercent: Double
    var notes: String

    init(
        id: UUID = UUID(),
        title: String,
        subjectId: UUID? = nil,
        classId: UUID? = nil,
        courseId: UUID? = nil,
        termId: UUID? = nil,
        date: Date = Date(),
        category: AssessmentCategory = .other,
        weightingPercent: Double = 100,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.subjectId = subjectId
        self.classId = classId
        self.courseId = courseId
        self.termId = termId
        self.date = date
        self.categoryRawValue = category.rawValue
        self.weightingPercent = weightingPercent
        self.notes = notes
    }

    var category: AssessmentCategory {
        get { AssessmentCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }
}

@Model
final class GradeComment {
    var id: UUID
    var gradeEntryId: UUID
    var text: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        gradeEntryId: UUID,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.gradeEntryId = gradeEntryId
        self.text = text
        self.createdAt = createdAt
    }
}

@Model
final class GradeEntry {
    var id: UUID
    var assessmentId: UUID?
    // Legacy compatibility field. Prefer `resolvedStudentID` from `gradebookRow`.
    var studentId: UUID
    // A grade entry belongs to the concrete row context in which it was recorded.
    var gradebookRow: GradebookRowEntity?
    var semesterId: String
    var categoryKey: String
    var rawValue: String
    var value: Double?

    init(
        gradebookRow: GradebookRowEntity,
        assessmentId: UUID? = nil,
        semesterId: String,
        categoryKey: String,
        rawValue: String = "",
        value: Double? = nil
    ) {
        guard let studentID = gradebookRow.classEnrollment?.student?.id else {
            preconditionFailure("GradeEntry requires a GradebookRow with a valid enrollment and student.")
        }
        self.id = UUID()
        self.assessmentId = assessmentId
        self.gradebookRow = gradebookRow
        self.studentId = studentID
        self.semesterId = semesterId
        self.categoryKey = categoryKey
        self.rawValue = rawValue
        self.value = value
    }

    var resolvedStudentID: UUID? {
        gradebookRow?.classEnrollment?.student?.id ?? studentId
    }
}
