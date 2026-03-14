import Foundation
import SwiftData

struct CSVImportResult {
    let delimiter: Character
    let headers: [String]
    let headerMapping: CSVHeaderMapping?
    let candidates: [CSVImportCandidate]
    let parsingErrors: [CSVImportIssue]

    var validationIssues: [CSVImportIssue] {
        candidates.flatMap(\.issues)
    }

    var validCandidates: [CSVImportCandidate] {
        candidates.filter { $0.validationStatus == .valid }
    }
}

struct CSVHeaderMapping {
    let firstNameColumnIndex: Int
    let lastNameColumnIndex: Int
}

struct CSVImportCandidate: Identifiable {
    let id = UUID()
    let rowIndex: Int
    let originalFirstName: String
    let originalLastName: String
    let normalizedFirstName: String
    let normalizedLastName: String
    let validationStatus: CSVImportValidationStatus
    let issues: [CSVImportIssue]

    var displayName: String {
        [originalFirstName, originalLastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct CSVImportMatchResult {
    let importCandidate: CSVImportCandidate
    let matchStatus: CSVImportMatchStatus
    let candidateMatches: [CSVStudentMatch]
    let issues: [CSVImportIssue]
}

struct CSVImportResolution {
    let importCandidate: CSVImportCandidate
    let matchResult: CSVImportMatchResult
    var resolutionAction: CSVImportResolutionAction

    var isComplete: Bool {
        switch resolutionAction {
        case .createNewStudent, .skip, .useExistingStudent:
            return true
        case .unresolved:
            return false
        }
    }
}

struct CSVImportCommitResult {
    let outcomes: [CSVImportCommitOutcome]

    var createdStudents: [Student] {
        outcomes.compactMap { $0.createdNewStudent ? $0.student : nil }
    }

    var reusedStudents: [Student] {
        outcomes.compactMap { !$0.createdNewStudent && $0.status == .committed ? $0.student : nil }
    }

    var skippedResolutions: [CSVImportCommitOutcome] {
        outcomes.filter { $0.status == .skipped }
    }
}

struct CSVImportCommitOutcome {
    let resolution: CSVImportResolution
    let status: CSVImportCommitStatus
    let student: Student?
    let enrollment: ClassEnrollment?
    let createdNewStudent: Bool
    let createdEnrollment: Bool
    let createdRows: Int
    let issues: [CSVImportIssue]
}

struct CSVStudentMatch {
    let student: Student
    let matchQuality: CSVImportMatchQuality
    let reason: String

    var contextSummary: String {
        let enrollmentSummaries = student.classEnrollments
            .compactMap { enrollment -> String? in
                guard let schoolClass = enrollment.schoolClass else { return nil }
                if let studentNumber = enrollment.studentNumber {
                    return "\(schoolClass.name) Nr. \(studentNumber)"
                }
                return schoolClass.name
            }
            .sorted()

        if !enrollmentSummaries.isEmpty {
            return "Klassen: \(enrollmentSummaries.joined(separator: ", "))"
        }

        let shortID = String(student.id.uuidString.prefix(6))
        return "Ohne Klassenzuordnung · ID \(shortID)"
    }

    var displayLabel: String {
        "\(student.fullName) — \(contextSummary)"
    }
}

enum CSVImportMatchStatus {
    case none
    case single
    case multiple
}

enum CSVImportMatchQuality: Int, Comparable {
    case none = 0
    case germanNormalized = 1
    case legacySegmented = 2
    case normalized = 3
    case exact = 4

    static func < (lhs: CSVImportMatchQuality, rhs: CSVImportMatchQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum CSVImportResolutionAction: Equatable {
    case unresolved
    case createNewStudent
    case useExistingStudent(studentID: UUID)
    case skip
}

enum CSVImportCommitStatus {
    case committed
    case skipped
    case rejected
}

enum CSVImportValidationStatus {
    case valid
    case invalid
}

struct CSVImportIssue: Identifiable, Hashable {
    let id = UUID()
    let severity: CSVImportIssueSeverity
    let scope: CSVImportIssueScope
    let message: String
}

enum CSVImportIssueSeverity: Hashable {
    case error
    case warning
}

enum CSVImportIssueScope: Hashable {
    case file
    case row(Int)
}

enum CSVImportService {
    private static let supportedDelimiters: [Character] = [";", ",", "\t"]
    private static let firstNameHeaders = [
        "vorname",
        "first name",
        "firstname",
        "given name",
        "givenname"
    ]
    private static let lastNameHeaders = [
        "nachname",
        "last name",
        "lastname",
        "surname",
        "family name",
        "familyname"
    ]

    static func load(from url: URL, encoding: String.Encoding = .utf8) throws -> CSVImportResult {
        let content = try String(contentsOf: url, encoding: encoding)
        return parseCandidates(from: content)
    }

    static func parseCandidates(from content: String) -> CSVImportResult {
        let lines = content.components(separatedBy: .newlines)
        let firstNonEmptyLine = lines.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let headerLine = firstNonEmptyLine else {
            return CSVImportResult(
                delimiter: ",",
                headers: [],
                headerMapping: nil,
                candidates: [],
                parsingErrors: [
                    CSVImportIssue(
                        severity: .error,
                        scope: .file,
                        message: "Die CSV-Datei ist leer."
                    )
                ]
            )
        }

        let delimiter = detectDelimiter(in: headerLine)
        let headers = parseLine(headerLine, delimiter: delimiter).map { normalizeHeader($0) }
        let headerMappingResult = mapHeaders(headers)

        guard let headerMapping = headerMappingResult.mapping else {
            return CSVImportResult(
                delimiter: delimiter,
                headers: headers,
                headerMapping: nil,
                candidates: [],
                parsingErrors: headerMappingResult.errors
            )
        }

        var candidates: [CSVImportCandidate] = []

        for (index, rawLine) in lines.enumerated() {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            guard rawLine != headerLine else { continue }

            let columns = parseLine(rawLine, delimiter: delimiter).map { cleanCellValue($0) }
            let firstName = value(at: headerMapping.firstNameColumnIndex, in: columns)
            let lastName = value(at: headerMapping.lastNameColumnIndex, in: columns)

            let issues = validateRow(
                rowIndex: index + 1,
                originalFirstName: firstName,
                originalLastName: lastName
            )

            let candidate = CSVImportCandidate(
                rowIndex: index + 1,
                originalFirstName: firstName,
                originalLastName: lastName,
                normalizedFirstName: normalizeName(firstName),
                normalizedLastName: normalizeName(lastName),
                validationStatus: issues.contains(where: { $0.severity == .error }) ? .invalid : .valid,
                issues: issues
            )
            candidates.append(candidate)
        }

        return CSVImportResult(
            delimiter: delimiter,
            headers: headers,
            headerMapping: headerMapping,
            candidates: candidates,
            parsingErrors: headerMappingResult.errors
        )
    }

    /// Legacy convenience path for the existing popup UI.
    static func parseStudentNames(from content: String) -> [String] {
        parseCandidates(from: content)
            .validCandidates
            .map(\.displayName)
    }

    static func matchCandidates(
        _ candidates: [CSVImportCandidate],
        against students: [Student]
    ) -> [CSVImportMatchResult] {
        candidates
            .filter { $0.validationStatus == .valid }
            .map { candidate in
                let matches = students.compactMap { student in
                    match(for: candidate, against: student)
                }
                .sorted { lhs, rhs in
                    if lhs.matchQuality != rhs.matchQuality {
                        return lhs.matchQuality > rhs.matchQuality
                    }
                    if lhs.student.lastName != rhs.student.lastName {
                        return lhs.student.lastName.localizedStandardCompare(rhs.student.lastName) == .orderedAscending
                    }
                    return lhs.student.firstName.localizedStandardCompare(rhs.student.firstName) == .orderedAscending
                }

                let matchStatus: CSVImportMatchStatus
                switch matches.count {
                case 0:
                    matchStatus = .none
                case 1:
                    matchStatus = .single
                default:
                    matchStatus = .multiple
                }

                return CSVImportMatchResult(
                    importCandidate: candidate,
                    matchStatus: matchStatus,
                    candidateMatches: matches,
                    issues: []
                )
            }
    }

    static func matchCandidates(
        _ candidates: [CSVImportCandidate],
        in context: ModelContext
    ) throws -> [CSVImportMatchResult] {
        let students = try context.fetch(FetchDescriptor<Student>())
        return matchCandidates(candidates, against: students)
    }

    static func makeInitialResolution(for matchResult: CSVImportMatchResult) -> CSVImportResolution {
        let action: CSVImportResolutionAction

        switch matchResult.matchStatus {
        case .none:
            action = .createNewStudent
        case .single, .multiple:
            action = .unresolved
        }

        return CSVImportResolution(
            importCandidate: matchResult.importCandidate,
            matchResult: matchResult,
            resolutionAction: action
        )
    }

    static func makeInitialResolutions(for matchResults: [CSVImportMatchResult]) -> [CSVImportResolution] {
        matchResults.map { makeInitialResolution(for: $0) }
    }

    @MainActor
    static func commitResolutions(
        _ resolutions: [CSVImportResolution],
        into schoolClass: SchoolClass,
        context: ModelContext
    ) throws -> CSVImportCommitResult {
        var outcomes: [CSVImportCommitOutcome] = []

        for resolution in resolutions {
            guard resolution.isComplete else {
                outcomes.append(
                    CSVImportCommitOutcome(
                        resolution: resolution,
                        status: .rejected,
                        student: nil,
                        enrollment: nil,
                        createdNewStudent: false,
                        createdEnrollment: false,
                        createdRows: 0,
                        issues: [
                            CSVImportIssue(
                                severity: .error,
                                scope: .row(resolution.importCandidate.rowIndex),
                                message: "Resolution ist nicht vollständig und kann nicht importiert werden."
                            )
                        ]
                    )
                )
                continue
            }

            switch resolution.resolutionAction {
            case .skip:
                outcomes.append(
                    CSVImportCommitOutcome(
                        resolution: resolution,
                        status: .skipped,
                        student: nil,
                        enrollment: nil,
                        createdNewStudent: false,
                        createdEnrollment: false,
                        createdRows: 0,
                        issues: []
                    )
                )

            case .createNewStudent:
                let student = Student(
                    firstName: resolution.importCandidate.originalFirstName,
                    lastName: resolution.importCandidate.originalLastName
                )
                context.insert(student)

                let outcome = commitStudent(
                    resolution: resolution,
                    student: student,
                    createdNewStudent: true,
                    into: schoolClass,
                    context: context
                )
                outcomes.append(outcome)

            case .useExistingStudent(let studentID):
                let descriptor = FetchDescriptor<Student>(predicate: #Predicate { $0.id == studentID })
                guard let student = try context.fetch(descriptor).first else {
                    outcomes.append(
                        CSVImportCommitOutcome(
                            resolution: resolution,
                            status: .rejected,
                            student: nil,
                            enrollment: nil,
                            createdNewStudent: false,
                            createdEnrollment: false,
                            createdRows: 0,
                            issues: [
                                CSVImportIssue(
                                    severity: .error,
                                    scope: .row(resolution.importCandidate.rowIndex),
                                    message: "Ausgewählter Student konnte nicht geladen werden."
                                )
                            ]
                        )
                    )
                    continue
                }

                let outcome = commitStudent(
                    resolution: resolution,
                    student: student,
                    createdNewStudent: false,
                    into: schoolClass,
                    context: context
                )
                outcomes.append(outcome)

            case .unresolved:
                outcomes.append(
                    CSVImportCommitOutcome(
                        resolution: resolution,
                        status: .rejected,
                        student: nil,
                        enrollment: nil,
                        createdNewStudent: false,
                        createdEnrollment: false,
                        createdRows: 0,
                        issues: [
                            CSVImportIssue(
                                severity: .error,
                                scope: .row(resolution.importCandidate.rowIndex),
                                message: "Unaufgelöste Resolution darf nicht commitet werden."
                            )
                        ]
                    )
                )
            }
        }

        try context.save()
        return CSVImportCommitResult(outcomes: outcomes)
    }

    private static func detectDelimiter(in line: String) -> Character {
        supportedDelimiters.max { lhs, rhs in
            line.filter { $0 == lhs }.count < line.filter { $0 == rhs }.count
        } ?? ","
    }

    private static func parseLine(_ line: String, delimiter: Character) -> [String] {
        var values: [String] = []
        var current = ""
        var isInsideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]

            if character == "\"" {
                let nextIndex = line.index(after: index)
                if isInsideQuotes, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    current.append("\"")
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == delimiter, !isInsideQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }

            index = line.index(after: index)
        }

        values.append(current)
        return values
    }

    private static func mapHeaders(_ headers: [String]) -> (mapping: CSVHeaderMapping?, errors: [CSVImportIssue]) {
        let firstNameMatches = indices(in: headers, matchingAnyOf: firstNameHeaders)
        let lastNameMatches = indices(in: headers, matchingAnyOf: lastNameHeaders)

        var errors: [CSVImportIssue] = []

        if firstNameMatches.isEmpty {
            errors.append(CSVImportIssue(severity: .error, scope: .file, message: "Pflichtspalte für Vorname fehlt."))
        }
        if lastNameMatches.isEmpty {
            errors.append(CSVImportIssue(severity: .error, scope: .file, message: "Pflichtspalte für Nachname fehlt."))
        }
        if firstNameMatches.count > 1 {
            errors.append(CSVImportIssue(severity: .error, scope: .file, message: "Header für Vorname ist nicht eindeutig."))
        }
        if lastNameMatches.count > 1 {
            errors.append(CSVImportIssue(severity: .error, scope: .file, message: "Header für Nachname ist nicht eindeutig."))
        }

        guard errors.isEmpty,
              let firstNameColumnIndex = firstNameMatches.first,
              let lastNameColumnIndex = lastNameMatches.first
        else {
            return (nil, errors)
        }

        return (
            CSVHeaderMapping(
                firstNameColumnIndex: firstNameColumnIndex,
                lastNameColumnIndex: lastNameColumnIndex
            ),
            []
        )
    }

    private static func validateRow(
        rowIndex: Int,
        originalFirstName: String,
        originalLastName: String
    ) -> [CSVImportIssue] {
        var issues: [CSVImportIssue] = []

        if originalFirstName.isEmpty {
            issues.append(
                CSVImportIssue(
                    severity: .error,
                    scope: .row(rowIndex),
                    message: "Vorname fehlt."
                )
            )
        }

        if originalLastName.isEmpty {
            issues.append(
                CSVImportIssue(
                    severity: .error,
                    scope: .row(rowIndex),
                    message: "Nachname fehlt."
                )
            )
        }

        return issues
    }

    private static func cleanCellValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private static func normalizeHeader(_ value: String) -> String {
        normalizeWhitespace(
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        )
    }

    private static func normalizeName(_ value: String) -> String {
        normalizeWhitespace(
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        )
    }

    private static func germanNormalize(_ value: String) -> String {
        normalizeName(value)
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
    }

    private static func normalizeWhitespace(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func indices(in headers: [String], matchingAnyOf aliases: [String]) -> [Int] {
        headers.enumerated()
            .compactMap { index, header in
                aliases.contains(header) ? index : nil
            }
    }

    private static func value(at index: Int, in columns: [String]) -> String {
        guard columns.indices.contains(index) else { return "" }
        return columns[index]
    }

    @MainActor
    private static func commitStudent(
        resolution: CSVImportResolution,
        student: Student,
        createdNewStudent: Bool,
        into schoolClass: SchoolClass,
        context: ModelContext
    ) -> CSVImportCommitOutcome {
        GradebookRepository.ensureDefaultTab(for: schoolClass, in: context)
        let existingEnrollment = schoolClass.enrollments.first { $0.student?.id == student.id }
        let hadRowsBeforeCommit = hasRows(for: student.id, in: schoolClass)

        let enrollment = GradebookRepository.enrollment(
            for: student,
            in: schoolClass,
            context: context
        )
        GradebookRepository.appendRows(for: enrollment, in: schoolClass, context: context)

        let createdRows = hadRowsBeforeCommit ? 0 : GradebookRepository.tabs(for: schoolClass)
            .filter { tab in
                GradebookRepository.rows(for: tab).contains { $0.resolvedStudentID == student.id }
            }
            .count

        return CSVImportCommitOutcome(
            resolution: resolution,
            status: .committed,
            student: student,
            enrollment: enrollment,
            createdNewStudent: createdNewStudent,
            createdEnrollment: existingEnrollment == nil,
            createdRows: createdRows,
            issues: []
        )
    }

    @MainActor
    private static func hasRows(for studentID: UUID, in schoolClass: SchoolClass) -> Bool {
        GradebookRepository.tabs(for: schoolClass).contains { tab in
            GradebookRepository.rows(for: tab).contains { $0.resolvedStudentID == studentID }
        }
    }

    private static func match(for candidate: CSVImportCandidate, against student: Student) -> CSVStudentMatch? {
        if student.firstName == candidate.originalFirstName,
           student.lastName == candidate.originalLastName {
            return CSVStudentMatch(
                student: student,
                matchQuality: .exact,
                reason: "exact"
            )
        }

        let normalizedStudentFirstName = normalizeName(student.firstName)
        let normalizedStudentLastName = normalizeName(student.lastName)

        if normalizedStudentFirstName == candidate.normalizedFirstName,
           normalizedStudentLastName == candidate.normalizedLastName {
            return CSVStudentMatch(
                student: student,
                matchQuality: .normalized,
                reason: "normalized"
            )
        }

        if matchesLegacySegmented(candidate: candidate, student: student) {
            return CSVStudentMatch(
                student: student,
                matchQuality: .legacySegmented,
                reason: "legacySegmented"
            )
        }

        if germanNormalize(student.firstName) == germanNormalize(candidate.originalFirstName),
           germanNormalize(student.lastName) == germanNormalize(candidate.originalLastName) {
            return CSVStudentMatch(
                student: student,
                matchQuality: .germanNormalized,
                reason: "germanNormalized"
            )
        }

        return nil
    }

    private static func matchesLegacySegmented(candidate: CSVImportCandidate, student: Student) -> Bool {
        let candidateFirstNameParts = candidate.originalFirstName
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard candidateFirstNameParts.count >= 2 else { return false }

        let legacyStudentFirstName = candidateFirstNameParts.first ?? ""
        let legacyStudentLastName = (candidateFirstNameParts.dropFirst() + [candidate.originalLastName])
            .joined(separator: " ")

        if student.firstName == legacyStudentFirstName,
           student.lastName == legacyStudentLastName {
            return true
        }

        let normalizedLegacyFirstName = normalizeName(legacyStudentFirstName)
        let normalizedLegacyLastName = normalizeName(legacyStudentLastName)

        return normalizeName(student.firstName) == normalizedLegacyFirstName &&
            normalizeName(student.lastName) == normalizedLegacyLastName
    }
}
