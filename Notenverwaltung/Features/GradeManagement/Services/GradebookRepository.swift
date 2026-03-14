import Foundation
import SwiftData

enum GradebookRepository {
    @MainActor
    static func studentID(for row: GradebookRowEntity) -> UUID? {
        row.resolvedStudentID
    }

    @MainActor
    static func activeEnrollments(for schoolClass: SchoolClass) -> [ClassEnrollment] {
        schoolClass.enrollments
            .filter(\.isActive)
            .sorted { ($0.studentNumber ?? 0) < ($1.studentNumber ?? 0) }
    }

    @MainActor
    static func enrollment(
        for student: Student,
        studentNumber: Int? = nil,
        in schoolClass: SchoolClass,
        context: ModelContext
    ) -> ClassEnrollment {
        if let existing = schoolClass.enrollments.first(where: { $0.student?.id == student.id }) {
            if existing.studentNumber == nil {
                existing.studentNumber = studentNumber
            }
            return existing
        }

        let enrollment = ClassEnrollment(
            student: student,
            schoolClass: schoolClass,
            studentNumber: studentNumber,
            joinedAt: Date(),
            isActive: true
        )
        context.insert(enrollment)
        return enrollment
    }

    @MainActor
    private static func rowEntity(forStudentID studentID: UUID, in tab: GradebookTabEntity) -> GradebookRowEntity? {
        rows(for: tab).first { $0.resolvedStudentID == studentID }
    }

    @MainActor
    static func bootstrapTabsIfNeeded(
        for schoolClass: SchoolClass,
        state: ClassGradebooksState,
        in context: ModelContext
    ) {
        guard schoolClass.gradebookTabs.isEmpty else {
            normalizeSortOrder(for: schoolClass, in: context)
            return
        }

        let sourceTabs: [GradebookTabState]
        if state.tabs.isEmpty {
            let defaultTab = GradebookTabState(
                schoolYear: schoolClass.schoolYear,
                gradebook: ClassGradebookState(root: GradeTileTree.standardRoot(), rows: [])
            )
            sourceTabs = [defaultTab]
        } else {
            sourceTabs = state.tabs
        }

        for (index, tab) in sourceTabs.enumerated() {
            let entity = GradebookTabEntity(
                id: tab.id,
                title: tab.schoolYear,
                sortOrder: index,
                roundingDecimals: tab.gradebook.roundingDecimals,
                schoolClass: schoolClass
            )
            context.insert(entity)
        }

        try? context.save()
    }

    @MainActor
    static func ensureDefaultTab(for schoolClass: SchoolClass, in context: ModelContext) {
        guard schoolClass.gradebookTabs.isEmpty else {
            normalizeSortOrder(for: schoolClass, in: context)
            return
        }
        let entity = GradebookTabEntity(
            title: schoolClass.schoolYear,
            sortOrder: 0,
            roundingDecimals: 2,
            schoolClass: schoolClass
        )
        context.insert(entity)
        try? context.save()
    }

    @MainActor
    static func tabs(for schoolClass: SchoolClass) -> [GradebookTabEntity] {
        schoolClass.gradebookTabs.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    @MainActor
    static func bootstrapRowsIfNeeded(
        for tab: GradebookTabEntity,
        state: ClassGradebookState,
        schoolClass: SchoolClass,
        in context: ModelContext
    ) {
        guard tab.rows.isEmpty else { return }

        var enrollmentsByStudentID: [UUID: ClassEnrollment] = [:]
        for enrollment in activeEnrollments(for: schoolClass) {
            guard let studentID = enrollment.student?.id else { continue }
            enrollmentsByStudentID[studentID] = enrollment
        }
        var insertedStudentIDs = Set<UUID>()
        var sortOrder = 0

        for row in state.rows {
            guard let enrollment = enrollmentsByStudentID[row.id],
                  let student = enrollment.student else { continue }
            let entity = GradebookRowEntity(
                sortOrder: sortOrder,
                tab: tab,
                classEnrollment: enrollment
            )
            context.insert(entity)
            insertedStudentIDs.insert(student.id)
            sortOrder += 1
        }

        let remainingEnrollments = activeEnrollments(for: schoolClass)
            .filter { !insertedStudentIDs.contains($0.student?.id ?? UUID()) }

        for enrollment in remainingEnrollments {
            let entity = GradebookRowEntity(
                sortOrder: sortOrder,
                tab: tab,
                classEnrollment: enrollment
            )
            context.insert(entity)
            sortOrder += 1
        }

        try? context.save()
    }

    @MainActor
    static func rows(for tab: GradebookTabEntity) -> [GradebookRowEntity] {
        tab.rows.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.resolvedStudentNumber < $1.resolvedStudentNumber
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    @MainActor
    static func bootstrapCellValuesIfNeeded(
        for tab: GradebookTabEntity,
        state: ClassGradebookState,
        in context: ModelContext
    ) {
        var rowsByID: [UUID: GradebookRowEntity] = [:]
        for row in rows(for: tab) {
            guard let studentID = row.resolvedStudentID else { continue }
            rowsByID[studentID] = row
        }
        let nodesByID = Dictionary(
            flatNodes(for: tab).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var hasInserted = false
        for row in state.rows {
            guard let rowEntity = rowsByID[row.id] else { continue }
            if !rowEntity.cellValues.isEmpty { continue }

            for (nodeID, rawValue) in row.inputValues {
                guard let nodeEntity = nodesByID[nodeID] else { continue }
                let cellValue = GradebookCellValueEntity(rawValue: rawValue, row: rowEntity, node: nodeEntity)
                context.insert(cellValue)
                hasInserted = true
            }
        }

        if hasInserted {
            try? context.save()
        }
    }

    @MainActor
    static func cellValues(for row: GradebookRowEntity) -> [UUID: String] {
        Dictionary(
            row.cellValues.compactMap { cellValue in
                guard let nodeID = cellValue.node?.id else { return nil }
                return (nodeID, cellValue.rawValue)
            },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    @MainActor
    static func createTab(title: String, for schoolClass: SchoolClass, in context: ModelContext) -> GradebookTabEntity {
        let nextSortOrder = (tabs(for: schoolClass).map(\.sortOrder).max() ?? -1) + 1
        let tab = GradebookTabEntity(
            title: title,
            sortOrder: nextSortOrder,
            schoolClass: schoolClass
        )
        context.insert(tab)
        try? context.save()
        return tab
    }

    @MainActor
    static func renameTab(_ tab: GradebookTabEntity, title: String, in context: ModelContext) {
        tab.title = title
        try? context.save()
    }

    @MainActor
    static func deleteTab(_ tab: GradebookTabEntity, in context: ModelContext) {
        context.delete(tab)
        normalizeSortOrder(for: tab.schoolClass, in: context)
    }

    @MainActor
    static func normalizeSortOrder(for schoolClass: SchoolClass?, in context: ModelContext) {
        guard let schoolClass else { return }
        for (index, tab) in tabs(for: schoolClass).enumerated() {
            tab.sortOrder = index
        }
        try? context.save()
    }

    @MainActor
    static func bootstrapNodesIfNeeded(
        for tab: GradebookTabEntity,
        root: GradeTileNode,
        in context: ModelContext
    ) {
        guard tab.nodes.isEmpty else { return }
        let normalizedRoot = GradeTileTree.normalizedRoot(root)
        let rootEntity = GradebookTreeService.makeEntityTree(from: normalizedRoot, tab: tab)
        context.insert(rootEntity)
        try? context.save()
    }

    @MainActor
    static func rootNode(for tab: GradebookTabEntity) -> GradeTileNode? {
        let rootEntity = tab.nodes
            .filter { $0.parent == nil }
            .sorted(by: GradebookTreeService.sortNodes)
            .first
        return rootEntity.map(GradebookTreeService.makeTree(from:))
    }

    @MainActor
    static func replaceNodeTree(
        for tab: GradebookTabEntity,
        root: GradeTileNode,
        in context: ModelContext
    ) {
        let root = GradeTileTree.normalizedRoot(root)
        let existingRoots = tab.nodes.filter { $0.parent == nil }

        if let existingRoot = existingRoots.first(where: { $0.id == root.id }) {
            // In-place update: preserves CellValue relationships on surviving nodes
            GradebookTreeService.updateEntityTree(
                existing: existingRoot, from: root, tab: tab, context: context
            )
            // Delete any other stale roots (shouldn't normally exist)
            for otherRoot in existingRoots where otherRoot.id != root.id {
                context.delete(otherRoot)
            }
        } else {
            // No matching root — fall back to delete + recreate
            for oldRoot in existingRoots {
                context.delete(oldRoot)
            }
            let rootEntity = GradebookTreeService.makeEntityTree(from: root, tab: tab)
            context.insert(rootEntity)
        }

        try? context.save()
    }

    @MainActor
    static func appendRows(
        for enrollment: ClassEnrollment,
        in schoolClass: SchoolClass,
        context: ModelContext
    ) {
        guard let studentID = enrollment.student?.id else { return }
        for tab in tabs(for: schoolClass) {
            guard rowEntity(forStudentID: studentID, in: tab) == nil else { continue }
            let nextSortOrder = (rows(for: tab).map(\.sortOrder).max() ?? -1) + 1
            let row = GradebookRowEntity(
                sortOrder: nextSortOrder,
                tab: tab,
                classEnrollment: enrollment
            )
            context.insert(row)
        }
        try? context.save()
    }

    @MainActor
    static func deleteRows(
        for studentID: UUID,
        in schoolClass: SchoolClass,
        context: ModelContext
    ) {
        for tab in tabs(for: schoolClass) {
            for row in rows(for: tab) where row.resolvedStudentID == studentID {
                context.delete(row)
            }
            normalizeRowSortOrder(for: tab)
        }
        try? context.save()
    }

    @MainActor
    static func normalizeRowSortOrder(for tab: GradebookTabEntity) {
        for (index, row) in rows(for: tab).enumerated() {
            row.sortOrder = index
        }
    }

    @MainActor
    static func moveStudent(
        _ studentID: UUID,
        using action: StudentInsertionAction,
        in schoolClass: SchoolClass,
        anchorTab: GradebookTabEntity,
        context: ModelContext
    ) {
        let anchorRows = rows(for: anchorTab)
        guard anchorRows.contains(where: { $0.resolvedStudentID == studentID }) else { return }

        var orderedIDs = anchorRows.compactMap(\.resolvedStudentID)
        orderedIDs.removeAll { $0 == studentID }

        let insertionIndex: Int
        switch action {
        case .beforeStudent(let targetID):
            guard let targetIndex = orderedIDs.firstIndex(of: targetID) else { return }
            insertionIndex = targetIndex
        case .afterStudent(let targetID):
            guard let targetIndex = orderedIDs.firstIndex(of: targetID) else { return }
            insertionIndex = targetIndex + 1
        }

        orderedIDs.insert(studentID, at: insertionIndex)

        for tab in tabs(for: schoolClass) {
            let tabRows = rows(for: tab)
            let rowsByID: [UUID: GradebookRowEntity] = Dictionary(
                tabRows.compactMap { row in
                    guard let studentID = row.resolvedStudentID else { return nil }
                    return (studentID, row)
                },
                uniquingKeysWith: { first, _ in first }
            )

            var nextSortOrder = 0
            for rowID in orderedIDs {
                guard let row = rowsByID[rowID] else { continue }
                row.sortOrder = nextSortOrder
                nextSortOrder += 1
            }

            for row in tabRows where !orderedIDs.contains(row.resolvedStudentID ?? UUID()) {
                row.sortOrder = nextSortOrder
                nextSortOrder += 1
            }
        }

        try? context.save()
    }

    @MainActor
    static func upsertCellValue(
        rawValue: String,
        rowID: UUID,
        nodeID: UUID,
        in tab: GradebookTabEntity,
        context: ModelContext
    ) {
        guard let row = rowEntity(forStudentID: rowID, in: tab),
              let node = flatNodes(for: tab).first(where: { $0.id == nodeID }) else { return }

        if let existing = row.cellValues.first(where: { $0.node?.id == nodeID }) {
            existing.rawValue = rawValue
        } else {
            let cellValue = GradebookCellValueEntity(rawValue: rawValue, row: row, node: node)
            context.insert(cellValue)
        }
        try? context.save()
    }

    @MainActor
    static func ensureCellValues(
        for tab: GradebookTabEntity,
        rowIDs: [UUID],
        nodeIDs: Set<UUID>,
        context: ModelContext
    ) {
        var rowsByID: [UUID: GradebookRowEntity] = [:]
        for row in rows(for: tab) {
            guard let studentID = row.resolvedStudentID else { continue }
            rowsByID[studentID] = row
        }
        let nodesByID = Dictionary(
            flatNodes(for: tab).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var hasInserted = false

        for rowID in rowIDs {
            guard let row = rowsByID[rowID] else { continue }
            let existingNodeIDs = Set(row.cellValues.compactMap(\.node?.id))
            for nodeID in nodeIDs where !existingNodeIDs.contains(nodeID) {
                guard let node = nodesByID[nodeID] else { continue }
                let cellValue = GradebookCellValueEntity(rawValue: "", row: row, node: node)
                context.insert(cellValue)
                hasInserted = true
            }
        }

        if hasInserted {
            try? context.save()
        }
    }

    @MainActor
    static func removeCellValues(
        for nodeIDs: Set<UUID>,
        in tab: GradebookTabEntity,
        context: ModelContext
    ) {
        guard !nodeIDs.isEmpty else { return }
        for row in rows(for: tab) {
            for cellValue in row.cellValues where nodeIDs.contains(cellValue.node?.id ?? UUID()) {
                context.delete(cellValue)
            }
        }
        try? context.save()
    }

    @MainActor
    static func flatNodes(for tab: GradebookTabEntity) -> [GradebookNodeEntity] {
        let rootNodes = tab.nodes
            .filter { $0.parent == nil }
            .sorted(by: GradebookTreeService.sortNodes)

        var result: [GradebookNodeEntity] = []
        for root in rootNodes {
            collectNodes(root, into: &result)
        }
        return result
    }

    @MainActor
    private static func collectNodes(_ node: GradebookNodeEntity, into result: inout [GradebookNodeEntity]) {
        result.append(node)
        for child in node.children.sorted(by: GradebookTreeService.sortNodes) {
            collectNodes(child, into: &result)
        }
    }
}
