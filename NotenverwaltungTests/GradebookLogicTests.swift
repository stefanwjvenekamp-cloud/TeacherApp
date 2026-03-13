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
        #expect(root.children.map(\.id) == [examID])
        #expect(snapshots.isEmpty)
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
