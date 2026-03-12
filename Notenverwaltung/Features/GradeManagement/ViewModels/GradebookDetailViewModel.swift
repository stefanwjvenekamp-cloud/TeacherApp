import Foundation
import SwiftData
import Observation

@Observable @MainActor
final class GradebookDetailViewModel {
    let schoolClass: SchoolClass
    let tab: GradebookTabEntity
    private let context: ModelContext

    // MARK: - Entity-Derived State

    /// The current in-memory node tree, kept in sync with entities.
    private(set) var root: GradeTileNode

    /// Current columns derived from the root tree.
    var columns: [GradebookColumn] {
        GradeTileTree.columns(from: root)
    }

    /// Current input node IDs.
    var inputNodeIDs: Set<UUID> {
        Set(columns.filter { $0.type == .input }.map { $0.nodeID })
    }

    /// Current rounding decimals from the tab entity.
    var roundingDecimals: Int {
        tab.roundingDecimals
    }

    /// Rows derived from entities. Each row maps to a student with their cell values.
    private(set) var rows: [StudentGradeRow]

    // MARK: - UI State

    var columnWidths: [UUID: CGFloat] = [:]
    var horizontalScrollOffset: CGFloat = 0
    var zoomScale: CGFloat = 1.0
    var baseZoomScale: CGFloat = 1.0
    var movingNodeID: UUID? = nil
    var settingsTarget: TileSettingsTarget? = nil
    var activeInputCell: GradeInputCellTarget? = nil
    var inputPopupDraft: String = ""
    var inputPopupCategory: GradeInputCategory = .numbers
    var showNewDialog: Bool = false
    var showAddStudentSheet: Bool = false
    var showAddStudentsPopup: Bool = false
    var addStudentNameDraft: String = ""
    var pendingDeleteNodeID: UUID? = nil
    var showDeleteNodeDialog: Bool = false
    var pendingDeleteStudentID: UUID? = nil
    var showDeleteStudentDialog: Bool = false
    var pendingClearCell: GradeInputCellTarget? = nil
    var showClearCellDialog: Bool = false
    var editingStudentID: UUID? = nil
    var editStudentOriginalName: String = ""

    // MARK: - Init

    init(schoolClass: SchoolClass, tab: GradebookTabEntity, context: ModelContext) {
        self.schoolClass = schoolClass
        self.tab = tab
        self.context = context
        let resolvedRoot = GradebookRepository.rootNode(for: tab) ?? GradeTileTree.emptyRoot()
        self.root = resolvedRoot
        self.rows = Self.buildRows(for: schoolClass, tab: tab, root: resolvedRoot, context: context)
    }

    // MARK: - Data Refresh

    /// Rebuild rows from entities.
    func refreshRows() {
        rows = Self.buildRows(for: schoolClass, tab: tab, root: root, context: context)
    }

    // MARK: - Node Mutations

    func addChild(to parentID: UUID, type: GradeTileType) {
        root = GradebookNodeService.addChild(
            to: parentID, type: type, root: root, tab: tab, context: context
        )
        refreshRows()
    }

    func addSiblingArea(after siblingID: UUID) {
        root = GradebookNodeService.addSiblingArea(
            after: siblingID, root: root, tab: tab, context: context
        )
        refreshRows()
    }

    func deleteNode(id: UUID) {
        root = GradebookNodeService.deleteNode(
            id: id, root: root, tab: tab, context: context
        )
        refreshRows()

        if movingNodeID == id { movingNodeID = nil }
        if settingsTarget?.id == id { settingsTarget = nil }
        if activeInputCell?.nodeID == id { activeInputCell = nil }
    }

    func updateWeightAndRedistribute(nodeID: UUID, newWeight: Double) {
        root = GradebookNodeService.updateWeightAndRedistribute(
            nodeID: nodeID, newWeight: newWeight, root: root, tab: tab, context: context
        )
    }

    func autoDistributeWeights(for parentID: UUID) {
        root = GradebookNodeService.autoDistributeWeights(
            for: parentID, root: root, tab: tab, context: context
        )
    }

    func updateNodeTitle(nodeID: UUID, newTitle: String) {
        root = GradebookNodeService.updateTitle(
            nodeID: nodeID, newTitle: newTitle, root: root, tab: tab, context: context
        )
    }

    func updateNodeColorStyle(nodeID: UUID, colorStyle: GradeTileColorStyle) {
        var newRoot = root
        GradeTileTree.updateNode(root: &newRoot, id: nodeID) { node in
            node.colorStyle = colorStyle
        }
        GradebookRepository.replaceNodeTree(for: tab, root: newRoot, in: context)
        root = newRoot
    }

    func executeInsertionAction(_ action: InsertionAction, draggedID: UUID) {
        root = GradebookNodeService.executeInsertionAction(
            action, draggedID: draggedID, root: root, tab: tab, context: context
        )
        refreshRows()
    }

    // MARK: - Cell Value Mutations

    func inputValue(rowID: UUID, nodeID: UUID) -> String {
        rows.first(where: { $0.id == rowID })?.inputValues[nodeID] ?? ""
    }

    func setInputValue(_ value: String, rowID: UUID, nodeID: UUID) {
        guard let rowIndex = rows.firstIndex(where: { $0.id == rowID }) else { return }
        rows[rowIndex].inputValues[nodeID] = value
        GradebookRepository.upsertCellValue(
            rawValue: value, rowID: rowID, nodeID: nodeID, in: tab, context: context
        )
    }

    // MARK: - Student Mutations

    func addStudent(named name: String) {
        guard let student = GradebookStudentService.addStudent(
            named: name, schoolClass: schoolClass, tab: tab,
            inputNodeIDs: inputNodeIDs, context: context
        ) else { return }

        var values: [UUID: String] = [:]
        for inputID in inputNodeIDs { values[inputID] = "" }
        rows.append(StudentGradeRow(
            id: student.id, studentName: student.fullName, inputValues: values
        ))
    }

    func addStudents(names: [String]) {
        let students = GradebookStudentService.addStudents(
            names: names, schoolClass: schoolClass, tab: tab,
            inputNodeIDs: inputNodeIDs, context: context
        )
        for student in students {
            var values: [UUID: String] = [:]
            for inputID in inputNodeIDs { values[inputID] = "" }
            rows.append(StudentGradeRow(
                id: student.id, studentName: student.fullName, inputValues: values
            ))
        }
    }

    func deleteStudent(id: UUID) {
        rows.removeAll { $0.id == id }
        GradebookStudentService.deleteStudent(
            id: id, schoolClass: schoolClass, context: context
        )
    }

    func renameStudent(studentID: UUID, fullName: String) {
        GradebookStudentService.renameStudent(
            studentID: studentID, fullName: fullName, context: context
        )
        if let index = rows.firstIndex(where: { $0.id == studentID }) {
            rows[index].studentName = fullName
        }
    }

    func currentStudentName(studentID: UUID) -> String? {
        let descriptor = FetchDescriptor<Student>(predicate: #Predicate { $0.id == studentID })
        return (try? context.fetch(descriptor))?.first?.fullName
    }

    // MARK: - Root Replacement

    func replaceRootAndSyncRows(_ newRoot: GradeTileNode) {
        GradebookRepository.replaceNodeTree(for: tab, root: newRoot, in: context)
        root = newRoot
        refreshRows()
    }

    // MARK: - Row Name Update (for inline editing)

    func updateRowStudentName(studentID: UUID, name: String) {
        guard let index = rows.firstIndex(where: { $0.id == studentID }) else { return }
        rows[index].studentName = name
    }

    // MARK: - Private

    private static func buildRows(
        for schoolClass: SchoolClass,
        tab: GradebookTabEntity,
        root: GradeTileNode,
        context: ModelContext
    ) -> [StudentGradeRow] {
        let inputIDs = Set(GradeTileTree.columns(from: root).filter { $0.type == .input }.map { $0.nodeID })
        let rowEntities = GradebookRepository.rows(for: tab)
        GradebookRepository.ensureCellValues(
            for: tab,
            rowIDs: rowEntities.map(\.id),
            nodeIDs: inputIDs,
            context: context
        )

        return rowEntities.compactMap { rowEntity in
            guard let student = rowEntity.student else { return nil }
            var values = GradebookRepository.cellValues(for: rowEntity)
            values = values.filter { inputIDs.contains($0.key) }
            for inputID in inputIDs where values[inputID] == nil {
                values[inputID] = ""
            }
            return StudentGradeRow(
                id: student.id,
                studentName: student.fullName,
                inputValues: values
            )
        }
    }
}
