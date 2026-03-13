import Foundation
import SwiftData

@MainActor
struct GradebookDetailInteractor {
    let schoolClass: SchoolClass
    let tab: GradebookTabEntity
    private let context: ModelContext

    init(schoolClass: SchoolClass, tab: GradebookTabEntity, context: ModelContext) {
        self.schoolClass = schoolClass
        self.tab = tab
        self.context = context
    }

    func loadRoot() -> GradeTileNode {
        GradebookRepository.rootNode(for: tab) ?? GradeTileTree.emptyRoot()
    }

    func buildRows(root: GradeTileNode) -> [StudentGradeRow] {
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

    func addChild(to parentID: UUID, type: GradeTileType, root: GradeTileNode) -> GradeTileNode {
        GradebookNodeService.addChild(
            to: parentID,
            type: type,
            root: root,
            tab: tab,
            context: context
        )
    }

    func addSiblingArea(after siblingID: UUID, root: GradeTileNode) -> GradeTileNode {
        GradebookNodeService.addSiblingArea(
            after: siblingID,
            root: root,
            tab: tab,
            context: context
        )
    }

    func mergeSiblingNodesUnderNewParent(nodeIDs: [UUID], root: GradeTileNode) -> GradeTileNode {
        GradebookNodeService.mergeSiblingNodesUnderNewParent(
            nodeIDs: nodeIDs,
            root: root,
            tab: tab,
            context: context
        )
    }

    func deleteNode(id: UUID, root: GradeTileNode) -> GradeTileNode {
        GradebookNodeService.deleteNode(
            id: id,
            root: root,
            tab: tab,
            context: context
        )
    }

    func updateWeightAndRedistribute(nodeID: UUID, newWeight: Double, root: GradeTileNode) -> GradeTileNode {
        GradebookNodeService.updateWeightAndRedistribute(
            nodeID: nodeID,
            newWeight: newWeight,
            root: root,
            tab: tab,
            context: context
        )
    }

    func autoDistributeWeights(for parentID: UUID, root: GradeTileNode) -> GradeTileNode {
        GradebookNodeService.autoDistributeWeights(
            for: parentID,
            root: root,
            tab: tab,
            context: context
        )
    }

    func updateNodeTitle(nodeID: UUID, newTitle: String, root: GradeTileNode) -> GradeTileNode {
        GradebookNodeService.updateTitle(
            nodeID: nodeID,
            newTitle: newTitle,
            root: root,
            tab: tab,
            context: context
        )
    }

    func updateNodeColorStyle(nodeID: UUID, colorStyle: GradeTileColorStyle, root: GradeTileNode) -> GradeTileNode {
        var newRoot = root
        GradeTileTree.updateNode(root: &newRoot, id: nodeID) { node in
            node.colorStyle = colorStyle
        }
        GradebookRepository.replaceNodeTree(for: tab, root: newRoot, in: context)
        return newRoot
    }

    func executeInsertionAction(_ action: InsertionAction, draggedID: UUID, root: GradeTileNode) -> GradeTileNode {
        GradebookNodeService.executeInsertionAction(
            action,
            draggedID: draggedID,
            root: root,
            tab: tab,
            context: context
        )
    }

    func setInputValue(_ value: String, rowID: UUID, nodeID: UUID) {
        GradebookRepository.upsertCellValue(
            rawValue: value,
            rowID: rowID,
            nodeID: nodeID,
            in: tab,
            context: context
        )
    }

    func addStudent(named name: String, inputNodeIDs: Set<UUID>) -> Student? {
        GradebookStudentService.addStudent(
            named: name,
            schoolClass: schoolClass,
            tab: tab,
            inputNodeIDs: inputNodeIDs,
            context: context
        )
    }

    func addStudents(names: [String], inputNodeIDs: Set<UUID>) -> [Student] {
        GradebookStudentService.addStudents(
            names: names,
            schoolClass: schoolClass,
            tab: tab,
            inputNodeIDs: inputNodeIDs,
            context: context
        )
    }

    func deleteStudent(id: UUID) {
        GradebookStudentService.deleteStudent(
            id: id,
            schoolClass: schoolClass,
            context: context
        )
    }

    func renameStudent(studentID: UUID, fullName: String) {
        GradebookStudentService.renameStudent(
            studentID: studentID,
            fullName: fullName,
            context: context
        )
    }

    func currentStudentName(studentID: UUID) -> String? {
        let descriptor = FetchDescriptor<Student>(predicate: #Predicate { $0.id == studentID })
        return (try? context.fetch(descriptor))?.first?.fullName
    }

    func replaceRootAndSyncRows(_ newRoot: GradeTileNode) {
        GradebookRepository.replaceNodeTree(for: tab, root: newRoot, in: context)
    }
}
