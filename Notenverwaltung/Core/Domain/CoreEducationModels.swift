import Foundation
import SwiftData

@Model
final class Teacher {
    var id: UUID
    var firstName: String
    var lastName: String
    var abbreviation: String
    var email: String

    init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String,
        abbreviation: String = "",
        email: String = ""
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.abbreviation = abbreviation
        self.email = email
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

@Model
final class Subject {
    var id: UUID
    var name: String
    var shortCode: String

    init(id: UUID = UUID(), name: String, shortCode: String = "") {
        self.id = id
        self.name = name
        self.shortCode = shortCode
    }
}

@Model
final class SchoolYear {
    var id: UUID
    var label: String
    var startYear: Int
    var endYear: Int

    init(id: UUID = UUID(), label: String, startYear: Int, endYear: Int) {
        self.id = id
        self.label = label
        self.startYear = startYear
        self.endYear = endYear
    }
}

@Model
final class Term {
    var id: UUID
    var title: String
    var orderIndex: Int
    var schoolYearId: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        orderIndex: Int,
        schoolYearId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.orderIndex = orderIndex
        self.schoolYearId = schoolYearId
    }
}

@Model
final class SchoolClass {
    var id: UUID
    var name: String
    var subject: String
    var schoolYear: String
    var createdAt: Date

    // Deleting a class removes its memberships. An enrollment without its class is invalid.
    @Relationship(deleteRule: .cascade, inverse: \ClassEnrollment.schoolClass)
    var enrollments: [ClassEnrollment]

    @Relationship(deleteRule: .cascade, inverse: \GradebookTabEntity.schoolClass)
    var gradebookTabs: [GradebookTabEntity]

    var homeroomTeacherId: UUID?
    var courseIDs: [UUID]

    init(name: String, subject: String, schoolYear: String) {
        self.id = UUID()
        self.name = name
        self.subject = subject
        self.schoolYear = schoolYear
        self.createdAt = Date()
        self.enrollments = []
        self.gradebookTabs = []
        self.homeroomTeacherId = nil
        self.courseIDs = []
    }

    var displayName: String {
        "\(name) - \(subject)"
    }
}

@Model
final class ClassEnrollment {
    var id: UUID
    var studentNumber: Int?
    var joinedAt: Date?
    var isActive: Bool

    // SwiftData keeps relationships optional in storage, but construction must provide both sides.
    var student: Student?
    var schoolClass: SchoolClass?
    // Rows are projections of a class membership and must not outlive that membership.
    @Relationship(deleteRule: .cascade, inverse: \GradebookRowEntity.classEnrollment)
    var gradebookRows: [GradebookRowEntity]

    init(
        id: UUID = UUID(),
        student: Student,
        schoolClass: SchoolClass,
        studentNumber: Int? = nil,
        joinedAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.student = student
        self.schoolClass = schoolClass
        self.studentNumber = studentNumber
        self.joinedAt = joinedAt
        self.isActive = isActive
        self.gradebookRows = []
    }
}

@Model
final class Course {
    var id: UUID
    var title: String
    var classId: UUID?
    var subjectId: UUID?
    var teacherId: UUID?
    var schoolYearId: UUID?
    var termId: UUID?
    // Legacy membership path. Do not write new course memberships here; replace with CourseEnrollment later.
    private(set) var enrolledStudentIDs: [UUID]

    init(
        id: UUID = UUID(),
        title: String,
        classId: UUID? = nil,
        subjectId: UUID? = nil,
        teacherId: UUID? = nil,
        schoolYearId: UUID? = nil,
        termId: UUID? = nil,
        enrolledStudentIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.classId = classId
        self.subjectId = subjectId
        self.teacherId = teacherId
        self.schoolYearId = schoolYearId
        self.termId = termId
        self.enrolledStudentIDs = enrolledStudentIDs
    }
}

@Model
final class Student {
    var id: UUID
    var firstName: String
    var lastName: String

    // Legacy path. Keep compatible until all grade data reads through GradebookRow.
    @Relationship(deleteRule: .cascade)
    var gradeEntries: [GradeEntry]

    // Deleting a student removes all memberships. An enrollment without its person is invalid.
    @Relationship(deleteRule: .cascade, inverse: \ClassEnrollment.student)
    var classEnrollments: [ClassEnrollment]

    // Legacy membership path. Do not write new course memberships here; replace with CourseEnrollment later.
    private(set) var courseIDs: [UUID]

    init(firstName: String, lastName: String) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.gradeEntries = []
        self.classEnrollments = []
        self.courseIDs = []
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
