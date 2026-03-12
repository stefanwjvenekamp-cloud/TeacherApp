import Foundation
import SwiftData
import Observation

@Observable @MainActor
final class GradebookDetailViewModel {
    let schoolClass: SchoolClass
    let tab: GradebookTabEntity
    private let interactor: GradebookDetailInteractor

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
        self.interactor = GradebookDetailInteractor(
            schoolClass: schoolClass,
            tab: tab,
            context: context
        )
        let resolvedRoot = interactor.loadRoot()
        self.root = resolvedRoot
        self.rows = interactor.buildRows(root: resolvedRoot)
    }

    // MARK: - Data Refresh

    /// Rebuild rows from entities.
    func refreshRows() {
        rows = interactor.buildRows(root: root)
    }

    // MARK: - Node Mutations

    func addChild(to parentID: UUID, type: GradeTileType) {
        root = interactor.addChild(to: parentID, type: type, root: root)
        refreshRows()
    }

    func addSiblingArea(after siblingID: UUID) {
        root = interactor.addSiblingArea(after: siblingID, root: root)
        refreshRows()
    }

    func deleteNode(id: UUID) {
        root = interactor.deleteNode(id: id, root: root)
        refreshRows()

        if movingNodeID == id { movingNodeID = nil }
        if settingsTarget?.id == id { settingsTarget = nil }
        if activeInputCell?.nodeID == id { activeInputCell = nil }
    }

    func updateWeightAndRedistribute(nodeID: UUID, newWeight: Double) {
        root = interactor.updateWeightAndRedistribute(nodeID: nodeID, newWeight: newWeight, root: root)
    }

    func autoDistributeWeights(for parentID: UUID) {
        root = interactor.autoDistributeWeights(for: parentID, root: root)
    }

    func updateNodeTitle(nodeID: UUID, newTitle: String) {
        root = interactor.updateNodeTitle(nodeID: nodeID, newTitle: newTitle, root: root)
    }

    func updateNodeColorStyle(nodeID: UUID, colorStyle: GradeTileColorStyle) {
        root = interactor.updateNodeColorStyle(nodeID: nodeID, colorStyle: colorStyle, root: root)
    }

    func executeInsertionAction(_ action: InsertionAction, draggedID: UUID) {
        root = interactor.executeInsertionAction(action, draggedID: draggedID, root: root)
        refreshRows()
    }

    // MARK: - Cell Value Mutations

    func inputValue(rowID: UUID, nodeID: UUID) -> String {
        rows.first(where: { $0.id == rowID })?.inputValues[nodeID] ?? ""
    }

    func setInputValue(_ value: String, rowID: UUID, nodeID: UUID) {
        guard let rowIndex = rows.firstIndex(where: { $0.id == rowID }) else { return }
        rows[rowIndex].inputValues[nodeID] = value
        interactor.setInputValue(value, rowID: rowID, nodeID: nodeID)
    }

    // MARK: - Student Mutations

    func addStudent(named name: String) {
        guard let student = interactor.addStudent(named: name, inputNodeIDs: inputNodeIDs) else { return }

        var values: [UUID: String] = [:]
        for inputID in inputNodeIDs { values[inputID] = "" }
        rows.append(StudentGradeRow(
            id: student.id, studentName: student.fullName, inputValues: values
        ))
    }

    func addStudents(names: [String]) {
        let students = interactor.addStudents(names: names, inputNodeIDs: inputNodeIDs)
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
        interactor.deleteStudent(id: id)
    }

    func renameStudent(studentID: UUID, fullName: String) {
        interactor.renameStudent(studentID: studentID, fullName: fullName)
        if let index = rows.firstIndex(where: { $0.id == studentID }) {
            rows[index].studentName = fullName
        }
    }

    func currentStudentName(studentID: UUID) -> String? {
        interactor.currentStudentName(studentID: studentID)
    }

    // MARK: - Root Replacement

    func replaceRootAndSyncRows(_ newRoot: GradeTileNode) {
        interactor.replaceRootAndSyncRows(newRoot)
        root = newRoot
        refreshRows()
    }

    // MARK: - Row Name Update (for inline editing)

    func updateRowStudentName(studentID: UUID, name: String) {
        guard let index = rows.firstIndex(where: { $0.id == studentID }) else { return }
        rows[index].studentName = name
    }

}
