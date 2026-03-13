import Foundation
import SwiftData
import Testing
@testable import Notenverwaltung

struct CSVImportServiceTests {
    @Test func parsesHeaderedAndNumberedRows() {
        let csv = """
        Nr.;Nachname;Vorname
        1;Meyer;Anna
        2;Schulz;Ben
        """

        let names = CSVImportService.parseStudentNames(from: csv)

        #expect(names == ["Meyer Anna", "Schulz Ben"])
    }

    @Test func skipsHeaderRowsAndKeepsSingleColumnNames() {
        let csv = """
        Schülername
        Anna Meyer
        
        Ben Schulz
        """

        let names = CSVImportService.parseStudentNames(from: csv)

        #expect(names == ["Anna Meyer", "Ben Schulz"])
    }

    @Test func fallsBackToFirstNonEmptyColumnWhenSecondColumnIsMissing() {
        let csv = """
        Nachname;Vorname
        Meyer;
        ;Ben
        Schulz;Tom
        """

        let names = CSVImportService.parseStudentNames(from: csv)

        #expect(names == ["Meyer", "Schulz Tom"])
    }
}

struct GradeTileTreeCalculationTests {
    @Test func calculatesWeightedAverageUsingAvailableValuesOnly() {
        let examID = UUID()
        let oralID = UUID()
        let root = GradeTileNode(
            title: "Gesamt",
            type: .calculation,
            children: [
                GradeTileNode(id: examID, title: "Klassenarbeit", type: .input, weightPercent: 70),
                GradeTileNode(id: oralID, title: "Mitarbeit", type: .input, weightPercent: 30)
            ]
        )
        let row = StudentGradeRow(studentName: "Anna", inputValues: [examID: "2,0"])

        let value = GradeTileTree.calculateValue(for: root, row: row, roundingDecimals: 2)

        #expect(value == 2.0)
    }
}

struct GradeTileTreeTechnicalRootTests {
    @Test func standardAndEmptyRootsAreCreatedDirectlyAsTechnicalRoots() {
        let standardRoot = GradeTileTree.standardRoot()
        let emptyRoot = GradeTileTree.emptyRoot()

        #expect(standardRoot.isTechnicalRoot)
        #expect(standardRoot.showsAsColumn == false)
        #expect(standardRoot.children.count == 1)
        #expect(standardRoot.children.first?.title == "Schuljahr")
        #expect(standardRoot.children.first?.isTechnicalRoot == false)

        #expect(emptyRoot.isTechnicalRoot)
        #expect(emptyRoot.showsAsColumn == false)
        #expect(emptyRoot.children.count == 1)
        #expect(emptyRoot.children.first?.title == "Schuljahr")
        #expect(emptyRoot.children.first?.children.isEmpty == true)
    }

    @Test func normalizesOldVisibleRootTreesPreservingVisibleIDsAndExcludingTechnicalRootFromColumns() {
        let visibleRootID = UUID()
        let childID = UUID()
        let oldRoot = GradeTileNode(
            id: visibleRootID,
            title: "Schuljahr",
            type: .calculation,
            children: [
                GradeTileNode(id: childID, title: "Halbjahr 1", type: .input, weightPercent: 100)
            ]
        )

        let normalizedRoot = GradeTileTree.normalizedRoot(oldRoot)
        let columnIDs = GradeTileTree.columns(from: normalizedRoot).map(\.nodeID)

        #expect(normalizedRoot.isTechnicalRoot)
        #expect(normalizedRoot.type == .calculation)
        #expect(normalizedRoot.showsAsColumn == false)
        #expect(normalizedRoot.children.map(\.id) == [visibleRootID])
        #expect(normalizedRoot.children.first?.children.map(\.id) == [childID])
        #expect(!columnIDs.contains(normalizedRoot.id))
        #expect(columnIDs == [visibleRootID, childID])
    }

    @Test func doesNotDoubleWrapAlreadyMigratedTrees() {
        let visibleRoot = GradeTileNode(title: "Schuljahr", type: .calculation, children: [])
        let technicalRoot = GradeTileTree.technicalRoot(children: [visibleRoot])

        let normalizedRoot = GradeTileTree.normalizedRoot(technicalRoot)

        #expect(normalizedRoot.id == technicalRoot.id)
        #expect(normalizedRoot.children.map(\.id) == technicalRoot.children.map(\.id))
        #expect(normalizedRoot.isTechnicalRoot)
    }

    @Test func defaultRootsUseSchuljahrAsFirstVisibleTitle() {
        #expect(GradeTileTree.standardRoot().children.first?.title == "Schuljahr")
        #expect(GradeTileTree.emptyRoot().children.first?.title == "Schuljahr")
    }
}

struct GradeTileTreeMutationTests {
    @Test func insertsSiblingBeforeAndRemovesNode() {
        let firstID = UUID()
        let secondID = UUID()
        let insertedID = UUID()
        var root = GradeTileNode(
            title: "Schuljahr",
            type: .calculation,
            children: [
                GradeTileNode(id: firstID, title: "A", type: .input),
                GradeTileNode(id: secondID, title: "B", type: .input)
            ]
        )

        GradeTileTree.insertAtSameLevel(
            root: &root,
            siblingID: secondID,
            node: GradeTileNode(id: insertedID, title: "Neu", type: .input),
            after: false
        )
        let removed = GradeTileTree.removeNode(root: &root, id: secondID)

        #expect(root.children.map(\.id) == [firstID, insertedID])
        #expect(removed?.id == secondID)
    }
}

struct GradebookNodeServiceMergeTests {
    @MainActor
    @Test func mergesRootLevelSiblingsUnderNewParentPreservingOrderAndSubtrees() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0)
        context.insert(schoolClass)
        context.insert(tab)

        let firstAreaID = UUID()
        let secondAreaID = UUID()
        let thirdAreaID = UUID()
        let firstLeafID = UUID()
        let secondLeafID = UUID()

        let root = GradeTileNode(
            title: "Schuljahr",
            type: .calculation,
            children: [
                GradeTileNode(
                    id: firstAreaID,
                    title: "Halbjahr 1",
                    type: .calculation,
                    children: [
                        GradeTileNode(id: firstLeafID, title: "KA 1", type: .input, weightPercent: 100)
                    ]
                ),
                GradeTileNode(
                    id: secondAreaID,
                    title: "Halbjahr 2",
                    type: .calculation,
                    children: [
                        GradeTileNode(id: secondLeafID, title: "KA 2", type: .input, weightPercent: 100)
                    ]
                ),
                GradeTileNode(id: thirdAreaID, title: "Mündlich", type: .input)
            ]
        )

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        let mergedRoot = GradebookNodeService.mergeSiblingNodesUnderNewParent(
            nodeIDs: [secondAreaID, firstAreaID],
            root: root,
            tab: tab,
            context: context
        )

        #expect(mergedRoot.children.count == 2)
        #expect(mergedRoot.children.map(\.id).contains(thirdAreaID))
        #expect(mergedRoot.children.map(\.weightPercent) == [50, 50])

        let mergedParent = try #require(mergedRoot.children.first)
        #expect(mergedParent.title == "Neuer Oberbereich")
        #expect(mergedParent.type == .calculation)
        #expect(mergedParent.children.map(\.id) == [firstAreaID, secondAreaID])
        #expect(mergedParent.children.map(\.weightPercent) == [50, 50])
        #expect(mergedParent.children.first?.children.map(\.id) == [firstLeafID])
        #expect(mergedParent.children.dropFirst().first?.children.map(\.id) == [secondLeafID])
    }

    @MainActor
    @Test func doesNotMutateWhenNodesDoNotShareSameParent() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0)
        context.insert(schoolClass)
        context.insert(tab)

        let siblingID = UUID()
        let nestedParentID = UUID()
        let nestedID = UUID()
        let root = GradeTileNode(
            title: "Schuljahr",
            type: .calculation,
            children: [
                GradeTileNode(
                    id: nestedParentID,
                    title: "Bereich",
                    type: .calculation,
                    children: [
                        GradeTileNode(id: nestedID, title: "KA", type: .input)
                    ]
                ),
                GradeTileNode(id: siblingID, title: "Mündlich", type: .input)
            ]
        )

        let mergedRoot = GradebookNodeService.mergeSiblingNodesUnderNewParent(
            nodeIDs: [nestedID, siblingID],
            root: root,
            tab: tab,
            context: context
        )

        #expect(mergedRoot == root)
    }
}

struct GradebookNodeServiceSiblingTests {
    @MainActor
    @Test func addsSiblingAreaForVisibleTopLevelNodeUnderTechnicalRoot() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0)
        context.insert(schoolClass)
        context.insert(tab)

        let visibleRootID = UUID()
        let nestedChildID = UUID()
        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(
                id: visibleRootID,
                title: "Schuljahr",
                type: .calculation,
                children: [
                    GradeTileNode(id: nestedChildID, title: "Halbjahr 1", type: .input, weightPercent: 100)
                ]
            )
        ])

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        let updatedRoot = GradebookNodeService.addSiblingArea(
            after: visibleRootID,
            root: root,
            tab: tab,
            context: context
        )

        #expect(updatedRoot.isTechnicalRoot)
        #expect(updatedRoot.children.count == 2)
        #expect(updatedRoot.children.first?.id == visibleRootID)
        #expect(updatedRoot.children.first?.children.map(\.id) == [nestedChildID])

        let insertedSibling = try #require(updatedRoot.children.last)
        #expect(insertedSibling.id != visibleRootID)
        #expect(insertedSibling.title == "Neuer Bereich")
        #expect(insertedSibling.type == .calculation)
        #expect(insertedSibling.children.isEmpty)

        let persistedRoot = try #require(GradebookRepository.rootNode(for: tab))
        #expect(persistedRoot.isTechnicalRoot)
        #expect(persistedRoot.children.map(\.id) == updatedRoot.children.map(\.id))
    }

    @MainActor
    @Test func addChildUsesPresetTitlesForCalculationAndInputNodes() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0)
        context.insert(schoolClass)
        context.insert(tab)

        let parentID = UUID()
        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(id: parentID, title: "Schuljahr", type: .calculation, children: [])
        ])

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        let rootWithCalculationChild = GradebookNodeService.addChild(
            to: parentID,
            type: .calculation,
            root: root,
            tab: tab,
            context: context
        )
        let calculationChild = try #require(GradeTileTree.findNode(in: rootWithCalculationChild, id: parentID)?.children.first)
        #expect(calculationChild.type == .calculation)
        #expect(calculationChild.title == "Neuer Bereich")

        let rootWithInputChild = GradebookNodeService.addChild(
            to: parentID,
            type: .input,
            root: rootWithCalculationChild,
            tab: tab,
            context: context
        )
        let inputChild = try #require(
            GradeTileTree.findNode(in: rootWithInputChild, id: parentID)?.children.first(where: { $0.type == .input })
        )
        #expect(inputChild.type == .input)
        #expect(inputChild.title == "Neue Notenspalte")
    }

    @MainActor
    @Test func addSiblingAreaUsesNeuerBereichTitle() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0)
        context.insert(schoolClass)
        context.insert(tab)

        let visibleRootID = UUID()
        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(id: visibleRootID, title: "Schuljahr", type: .calculation, children: [])
        ])

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        let updatedRoot = GradebookNodeService.addSiblingArea(
            after: visibleRootID,
            root: root,
            tab: tab,
            context: context
        )

        let insertedSibling = try #require(updatedRoot.children.last)
        #expect(insertedSibling.type == .calculation)
        #expect(insertedSibling.title == "Neuer Bereich")
    }
}

struct GradebookNodeServiceTopLevelMergeTests {
    @MainActor
    @Test func mergesVisibleTopLevelSiblingsUnderNewParentBelowTechnicalRoot() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0)
        context.insert(schoolClass)
        context.insert(tab)

        let firstAreaID = UUID()
        let secondAreaID = UUID()
        let firstLeafID = UUID()
        let secondLeafID = UUID()

        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(
                id: firstAreaID,
                title: "Schulhalbjahr 1",
                type: .calculation,
                children: [
                    GradeTileNode(id: firstLeafID, title: "KA 1", type: .input, weightPercent: 100)
                ]
            ),
            GradeTileNode(
                id: secondAreaID,
                title: "Schulhalbjahr 2",
                type: .calculation,
                children: [
                    GradeTileNode(id: secondLeafID, title: "KA 2", type: .input, weightPercent: 100)
                ]
            )
        ])

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        let mergedRoot = GradebookNodeService.mergeSiblingNodesUnderNewParent(
            nodeIDs: [firstAreaID, secondAreaID],
            root: root,
            tab: tab,
            context: context
        )

        #expect(mergedRoot.isTechnicalRoot)
        #expect(mergedRoot.children.count == 1)

        let mergedParent = try #require(mergedRoot.children.first)
        #expect(mergedParent.title == "Neuer Oberbereich")
        #expect(mergedParent.type == .calculation)
        #expect(mergedParent.children.map(\.id) == [firstAreaID, secondAreaID])
        #expect(mergedParent.children.first?.children.map(\.id) == [firstLeafID])
        #expect(mergedParent.children.dropFirst().first?.children.map(\.id) == [secondLeafID])

        let persistedRoot = try #require(GradebookRepository.rootNode(for: tab))
        #expect(persistedRoot.isTechnicalRoot)
        #expect(persistedRoot.children.count == 1)
        #expect(persistedRoot.children.first?.children.map(\.id) == [firstAreaID, secondAreaID])
    }

    @MainActor
    @Test func mergePreservesExistingEnteredValuesForMovedInputNodes() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0, schoolClass: schoolClass)
        context.insert(schoolClass)
        context.insert(tab)

        let student = Student(firstName: "Anna", lastName: "Meyer", studentNumber: 1, classId: schoolClass.id)
        schoolClass.students.append(student)
        let row = GradebookRowEntity(id: student.id, sortOrder: 0, tab: tab, student: student)
        context.insert(row)

        let firstAreaID = UUID()
        let secondAreaID = UUID()
        let firstInputID = UUID()
        let secondInputID = UUID()

        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(
                id: firstAreaID,
                title: "Schulhalbjahr 1",
                type: .calculation,
                children: [
                    GradeTileNode(id: firstInputID, title: "KA 1", type: .input, weightPercent: 100)
                ]
            ),
            GradeTileNode(
                id: secondAreaID,
                title: "Schulhalbjahr 2",
                type: .calculation,
                children: [
                    GradeTileNode(id: secondInputID, title: "KA 2", type: .input, weightPercent: 100)
                ]
            )
        ])

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        GradebookRepository.upsertCellValue(rawValue: "2", rowID: student.id, nodeID: firstInputID, in: tab, context: context)
        GradebookRepository.upsertCellValue(rawValue: "3", rowID: student.id, nodeID: secondInputID, in: tab, context: context)

        let mergedRoot = GradebookNodeService.mergeSiblingNodesUnderNewParent(
            nodeIDs: [firstAreaID, secondAreaID],
            root: root,
            tab: tab,
            context: context
        )

        let interactor = GradebookDetailInteractor(schoolClass: schoolClass, tab: tab, context: context)
        let rebuiltRows = interactor.buildRows(root: mergedRoot)
        let rebuiltRow = try #require(rebuiltRows.first)

        #expect(rebuiltRow.inputValues[firstInputID] == "2")
        #expect(rebuiltRow.inputValues[secondInputID] == "3")
        #expect(GradebookRepository.cellValues(for: row)[firstInputID] == "2")
        #expect(GradebookRepository.cellValues(for: row)[secondInputID] == "3")

        let reloadContext = ModelContext(container)
        let reloadedTab = try #require(fetchFirst(FetchDescriptor<GradebookTabEntity>(), in: reloadContext))
        let reloadedClass = try #require(fetchFirst(FetchDescriptor<SchoolClass>(), in: reloadContext))
        let reloadedInteractor = GradebookDetailInteractor(
            schoolClass: reloadedClass,
            tab: reloadedTab,
            context: reloadContext
        )
        let reloadedRoot = reloadedInteractor.loadRoot()
        let reloadedRows = reloadedInteractor.buildRows(root: reloadedRoot)
        let reloadedRow = try #require(reloadedRows.first)

        #expect(reloadedRow.inputValues[firstInputID] == "2")
        #expect(reloadedRow.inputValues[secondInputID] == "3")
    }

    @MainActor
    @Test func viewModelMergeFlowPreservesEnteredValuesAfterRefreshAndReload() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0, schoolClass: schoolClass)
        let student = Student(firstName: "Anna", lastName: "Meyer", studentNumber: 1, classId: schoolClass.id)
        schoolClass.students.append(student)
        context.insert(schoolClass)
        context.insert(tab)
        let row = GradebookRowEntity(id: student.id, sortOrder: 0, tab: tab, student: student)
        context.insert(row)
        try context.save()

        let viewModel = GradebookDetailViewModel(schoolClass: schoolClass, tab: tab, context: context)
        let firstVisibleArea = try #require(viewModel.root.children.first)

        viewModel.addSiblingArea(after: firstVisibleArea.id)

        let reloadedFirstArea = try #require(viewModel.root.children.first)
        let reloadedSecondArea = try #require(viewModel.root.children.dropFirst().first)

        viewModel.addChild(to: reloadedFirstArea.id, type: .input)
        viewModel.addChild(to: reloadedSecondArea.id, type: .input)

        let firstInputID = try #require(GradeTileTree.findNode(in: viewModel.root, id: reloadedFirstArea.id)?.children.first?.id)
        let secondInputID = try #require(GradeTileTree.findNode(in: viewModel.root, id: reloadedSecondArea.id)?.children.first?.id)

        viewModel.setInputValue("2", rowID: student.id, nodeID: firstInputID)
        viewModel.setInputValue("3", rowID: student.id, nodeID: secondInputID)
        viewModel.mergeSiblingNodesUnderNewParent(nodeIDs: [reloadedFirstArea.id, reloadedSecondArea.id])

        #expect(viewModel.inputValue(rowID: student.id, nodeID: firstInputID) == "2")
        #expect(viewModel.inputValue(rowID: student.id, nodeID: secondInputID) == "3")

        let reloadContext = ModelContext(container)
        let reloadedTab = try #require(fetchFirst(FetchDescriptor<GradebookTabEntity>(), in: reloadContext))
        let reloadedClass = try #require(fetchFirst(FetchDescriptor<SchoolClass>(), in: reloadContext))
        let reloadedViewModel = GradebookDetailViewModel(
            schoolClass: reloadedClass,
            tab: reloadedTab,
            context: reloadContext
        )

        #expect(reloadedViewModel.inputValue(rowID: student.id, nodeID: firstInputID) == "2")
        #expect(reloadedViewModel.inputValue(rowID: student.id, nodeID: secondInputID) == "3")
    }
}

struct GradebookNodeServiceMoveTests {
    @MainActor
    @Test func movingInputNodeAcrossParentsRedistributesWeights() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0, schoolClass: schoolClass)
        context.insert(schoolClass)
        context.insert(tab)

        let sourceParentID = UUID()
        let destinationParentID = UUID()
        let sourceLeafID = UUID()
        let siblingLeafID = UUID()
        let destinationLeafID = UUID()

        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(
                title: "Schuljahr",
                type: .calculation,
                children: [
                    GradeTileNode(
                        id: sourceParentID,
                        title: "Halbjahr 1",
                        type: .calculation,
                        weightPercent: 50,
                        children: [
                            GradeTileNode(id: sourceLeafID, title: "KA 1", type: .input, weightPercent: 50, isWeightManuallySet: true),
                            GradeTileNode(id: siblingLeafID, title: "KA 2", type: .input, weightPercent: 50, isWeightManuallySet: true)
                        ]
                    ),
                    GradeTileNode(
                        id: destinationParentID,
                        title: "Halbjahr 2",
                        type: .calculation,
                        weightPercent: 50,
                        children: [
                            GradeTileNode(id: destinationLeafID, title: "Mündlich", type: .input, weightPercent: 100, isWeightManuallySet: true)
                        ]
                    )
                ]
            )
        ])

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        let updatedRoot = GradebookNodeService.executeInsertionAction(
            .appendToParent(destinationParentID),
            draggedID: sourceLeafID,
            root: root,
            tab: tab,
            context: context
        )

        let updatedSourceParent = try #require(GradeTileTree.findNode(in: updatedRoot, id: sourceParentID))
        let updatedDestinationParent = try #require(GradeTileTree.findNode(in: updatedRoot, id: destinationParentID))

        #expect(updatedSourceParent.children.map(\.id) == [siblingLeafID])
        #expect(updatedSourceParent.children.first?.weightPercent == 100)
        #expect(updatedDestinationParent.children.map(\.id) == [destinationLeafID, sourceLeafID])
        #expect(updatedDestinationParent.children.map(\.weightPercent) == [50, 50])
    }

    @MainActor
    @Test func rejectingMoveIntoOwnDescendantKeepsTreeUnchanged() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0, schoolClass: schoolClass)
        context.insert(schoolClass)
        context.insert(tab)

        let parentID = UUID()
        let childID = UUID()
        let leafID = UUID()

        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(
                title: "Schuljahr",
                type: .calculation,
                children: [
                    GradeTileNode(
                        id: parentID,
                        title: "Halbjahr 1",
                        type: .calculation,
                        children: [
                            GradeTileNode(
                                id: childID,
                                title: "Unterbereich",
                                type: .calculation,
                                children: [
                                    GradeTileNode(id: leafID, title: "KA 1", type: .input, weightPercent: 100)
                                ]
                            )
                        ]
                    )
                ]
            )
        ])

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        let updatedRoot = GradebookNodeService.executeInsertionAction(
            .appendToParent(childID),
            draggedID: parentID,
            root: root,
            tab: tab,
            context: context
        )

        #expect(updatedRoot == root)
    }

    @MainActor
    @Test func movingInputNodePreservesExistingEnteredValueAfterReload() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0, schoolClass: schoolClass)
        context.insert(schoolClass)
        context.insert(tab)

        let student = Student(firstName: "Anna", lastName: "Meyer", studentNumber: 1, classId: schoolClass.id)
        schoolClass.students.append(student)

        let sourceParentID = UUID()
        let destinationParentID = UUID()
        let sourceLeafID = UUID()
        let destinationLeafID = UUID()

        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(
                title: "Schuljahr",
                type: .calculation,
                children: [
                    GradeTileNode(
                        id: sourceParentID,
                        title: "Bereich A",
                        type: .calculation,
                        weightPercent: 50,
                        children: [
                            GradeTileNode(id: sourceLeafID, title: "KA 1", type: .input, weightPercent: 100)
                        ]
                    ),
                    GradeTileNode(
                        id: destinationParentID,
                        title: "Bereich B",
                        type: .calculation,
                        weightPercent: 50,
                        children: [
                            GradeTileNode(id: destinationLeafID, title: "KA 2", type: .input, weightPercent: 100)
                        ]
                    )
                ]
            )
        ])

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        GradebookRepository.bootstrapRowsIfNeeded(
            for: tab,
            state: ClassGradebookState(root: root, rows: [StudentGradeRow(id: student.id, studentName: student.fullName)]),
            schoolClass: schoolClass,
            in: context
        )
        GradebookRepository.ensureCellValues(
            for: tab,
            rowIDs: [student.id],
            nodeIDs: [sourceLeafID, destinationLeafID],
            context: context
        )
        GradebookRepository.upsertCellValue(
            rawValue: "2",
            rowID: student.id,
            nodeID: sourceLeafID,
            in: tab,
            context: context
        )

        let movedRoot = GradebookNodeService.executeInsertionAction(
            .appendToParent(destinationParentID),
            draggedID: sourceLeafID,
            root: root,
            tab: tab,
            context: context
        )

        let rowAfterMove = try #require(GradebookRepository.rows(for: tab).first)
        #expect(GradebookRepository.cellValues(for: rowAfterMove)[sourceLeafID] == "2")

        let reloadContext = ModelContext(container)
        let reloadedTab = try #require(fetchFirst(FetchDescriptor<GradebookTabEntity>(), in: reloadContext))
        let reloadedClass = try #require(fetchFirst(FetchDescriptor<SchoolClass>(), in: reloadContext))
        let viewModel = GradebookDetailViewModel(schoolClass: reloadedClass, tab: reloadedTab, context: reloadContext)

        #expect(GradeTileTree.findNode(in: movedRoot, id: sourceLeafID) != nil)
        #expect(viewModel.inputValue(rowID: student.id, nodeID: sourceLeafID) == "2")
    }
}

struct GradebookMigrationServiceTests {
    @MainActor
    @Test func migratesLegacySnapshotsIntoTabsRowsAndCellValues() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        context.insert(schoolClass)

        let examID = UUID()
        let studentID = UUID()
        let tabID = UUID()
        let student = Student(firstName: "Anna", lastName: "Meyer", studentNumber: 1, classId: schoolClass.id)
        student.id = studentID
        schoolClass.students.append(student)
        let snapshotState = ClassGradebooksState(
            tabs: [
                GradebookTabState(
                    id: tabID,
                    schoolYear: "2025/2026",
                    gradebook: ClassGradebookState(
                        root: GradeTileNode(
                            title: "Schuljahr",
                            type: .calculation,
                            children: [
                                GradeTileNode(id: examID, title: "Klassenarbeit 1", type: .input, weightPercent: 100)
                            ]
                        ),
                        rows: [
                            StudentGradeRow(
                                id: studentID,
                                studentName: "Anna Meyer",
                                inputValues: [examID: "2"]
                            )
                        ],
                        roundingDecimals: 1
                    )
                )
            ],
            selectedTabID: tabID
        )
        let snapshotData = try JSONEncoder().encode(snapshotState)
        let snapshot = GradebookSnapshot(classId: schoolClass.id, data: snapshotData)
        context.insert(snapshot)
        try context.save()

        let didMigrate = GradebookMigrationService.migrateIfNeeded(context: context)

        #expect(didMigrate)

        let migratedClass = try #require(fetchFirst(FetchDescriptor<SchoolClass>(), in: context))
        let tab = try #require(GradebookRepository.tabs(for: migratedClass).first)
        let row = try #require(GradebookRepository.rows(for: tab).first)
        let root = try #require(GradebookRepository.rootNode(for: tab))
        let snapshots = try context.fetch(FetchDescriptor<GradebookSnapshot>())

        #expect(tab.id == tabID)
        #expect(tab.roundingDecimals == 1)
        #expect(migratedClass.students.count == 1)
        #expect(migratedClass.students.first?.fullName == "Anna Meyer")
        #expect(row.student?.id == studentID)
        #expect(GradebookRepository.cellValues(for: row)[examID] == "2")
        #expect(root.isTechnicalRoot)
        #expect(root.showsAsColumn == false)
        #expect(root.children.count == 1)
        #expect(root.children.first?.children.map(\.id) == [examID])
        #expect(snapshots.isEmpty)
    }
}

struct GradebookTechnicalRootPersistenceTests {
    @MainActor
    @Test func entityRoundTripPreservesTechnicalRootFlag() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0)
        context.insert(tab)

        let visibleRoot = GradeTileNode(title: "Schuljahr", type: .calculation, children: [])
        let technicalRoot = GradeTileTree.technicalRoot(children: [visibleRoot])

        let entityRoot = GradebookTreeService.makeEntityTree(from: technicalRoot, tab: tab)
        let roundTrippedRoot = GradebookTreeService.makeTree(from: entityRoot)

        #expect(roundTrippedRoot.isTechnicalRoot)
        #expect(roundTrippedRoot.showsAsColumn == false)
        #expect(roundTrippedRoot.children.first?.id == visibleRoot.id)
        #expect(roundTrippedRoot.children.first?.isTechnicalRoot == false)
    }

    @MainActor
    @Test func loadRootNormalizesLegacyPersistedTreesAndPersistsTheTechnicalRoot() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        let tab = GradebookTabEntity(title: "2025/2026", sortOrder: 0, schoolClass: schoolClass)
        context.insert(schoolClass)
        context.insert(tab)

        let visibleRootID = UUID()
        let childID = UUID()
        let legacyRoot = GradeTileNode(
            id: visibleRootID,
            title: "Schuljahr",
            type: .calculation,
            children: [
                GradeTileNode(id: childID, title: "Halbjahr 1", type: .input, weightPercent: 100)
            ]
        )
        let legacyEntityRoot = GradebookTreeService.makeEntityTree(from: legacyRoot, tab: tab)
        context.insert(legacyEntityRoot)
        try context.save()

        let interactor = GradebookDetailInteractor(schoolClass: schoolClass, tab: tab, context: context)
        let loadedRoot = interactor.loadRoot()
        let persistedRoot = try #require(GradebookRepository.rootNode(for: tab))

        #expect(loadedRoot.isTechnicalRoot)
        #expect(loadedRoot.children.map(\.id) == [visibleRootID])
        #expect(loadedRoot.children.first?.children.map(\.id) == [childID])
        #expect(persistedRoot.isTechnicalRoot)
        #expect(persistedRoot.children.map(\.id) == [visibleRootID])
    }
}

struct AppGradebookStoreCompatibilityTests {
    @Test func decodesLegacySingleGradebookEntryFormatIntoTabState() throws {
        let classID = UUID()
        let rowID = UUID()
        let legacyStore = LegacyEncodedAppGradebookStore(
            classes: [
                SavedClassData(
                    id: classID,
                    name: "10a",
                    subject: "Mathe",
                    schoolYear: "2025/2026"
                )
            ],
            gradebookEntries: [
                LegacyEncodedAppGradebookStore.LegacyGradebookEntry(
                    key: classID,
                    value: ClassGradebookState(
                        root: GradeTileNode(title: "Schuljahr", type: .calculation, children: []),
                        rows: [StudentGradeRow(id: rowID, studentName: "Anna Meyer", inputValues: [:])],
                        roundingDecimals: 2
                    )
                )
            ]
        )

        let store = try JSONDecoder().decode(
            AppGradebookStore.self,
            from: JSONEncoder().encode(legacyStore)
        )
        let migratedState = try #require(store.gradebooks[classID])
        let migratedTab = try #require(migratedState.tabs.first)

        #expect(store.classes.count == 1)
        #expect(migratedState.tabs.count == 1)
        #expect(migratedState.selectedTabID == migratedTab.id)
        #expect(migratedTab.schoolYear == "2025/2026")
        #expect(migratedTab.gradebook.rows.map(\.id) == [rowID])
    }
}

struct GradebookSeedNavigationTests {
    @MainActor
    @Test func seededClassesCanInitializeDetailViewModels() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        MockSeedDataService.seedIfNeeded(context: context)

        let descriptor = FetchDescriptor<SchoolClass>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let classes = try context.fetch(descriptor)

        #expect(classes.map(\.name) == ["10b", "5a"] || classes.map(\.name) == ["5a", "10b"])

        for schoolClass in classes {
            GradebookRepository.ensureDefaultTab(for: schoolClass, in: context)
            let tabs = GradebookRepository.tabs(for: schoolClass)
            let firstTab = try #require(tabs.first)
            let viewModel = GradebookDetailViewModel(
                schoolClass: schoolClass,
                tab: firstTab,
                context: context
            )

            #expect(!viewModel.columns.isEmpty)
            #expect(viewModel.rows.count == schoolClass.students.count)
        }
    }
}

struct GradebookStudentMoveTests {
    @MainActor
    @Test func movingStudentReordersRowsAcrossTabs() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let schoolClass = SchoolClass(name: "10a", subject: "Mathe", schoolYear: "2025/2026")
        context.insert(schoolClass)

        let first = Student(firstName: "Anna", lastName: "Meyer", studentNumber: 1, classId: schoolClass.id)
        let second = Student(firstName: "Ben", lastName: "Schulz", studentNumber: 2, classId: schoolClass.id)
        let third = Student(firstName: "Clara", lastName: "Becker", studentNumber: 3, classId: schoolClass.id)
        schoolClass.students = [first, second, third]

        let firstTab = GradebookTabEntity(title: "2025/2026", sortOrder: 0, schoolClass: schoolClass)
        let secondTab = GradebookTabEntity(title: "2026/2027", sortOrder: 1, schoolClass: schoolClass)
        context.insert(firstTab)
        context.insert(secondTab)

        for (index, student) in [first, second, third].enumerated() {
            context.insert(GradebookRowEntity(id: student.id, sortOrder: index, tab: firstTab, student: student))
            context.insert(GradebookRowEntity(id: student.id, sortOrder: index, tab: secondTab, student: student))
        }
        try context.save()

        GradebookRepository.moveStudent(
            first.id,
            using: .afterStudent(third.id),
            in: schoolClass,
            anchorTab: firstTab,
            context: context
        )

        #expect(GradebookRepository.rows(for: firstTab).map(\.id) == [second.id, third.id, first.id])
        #expect(GradebookRepository.rows(for: secondTab).map(\.id) == [second.id, third.id, first.id])
    }
}

@MainActor
private func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: PersistenceController.schema, configurations: [configuration])
}

private func fetchFirst<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, in context: ModelContext) -> T? {
    (try? context.fetch(descriptor))?.first
}

private struct LegacyEncodedAppGradebookStore: Encodable {
    let classes: [SavedClassData]
    let gradebookEntries: [LegacyGradebookEntry]

    struct LegacyGradebookEntry: Encodable {
        let key: UUID
        let value: ClassGradebookState
    }
}
