import SwiftUI
import SwiftData

#if DEBUG
private struct GradebookDetailPreviewFixture {
    let container: ModelContainer
    let context: ModelContext
    let schoolClass: SchoolClass
    let tab: GradebookTabEntity
}

@MainActor
private enum GradebookDetailPreviewFactory {
    static func makeMigratedRootFixture() -> GradebookDetailPreviewFixture {
        makeFixture(
            className: "10a",
            subject: "Mathematik",
            schoolYear: "2025/2026",
            root: GradeTileTree.standardRoot()
        )
    }

    static func makeMultipleTopLevelFixture() -> GradebookDetailPreviewFixture {
        let root = GradeTileTree.technicalRoot(children: [
            GradeTileNode(
                title: "Schuljahr",
                type: .calculation,
                weightPercent: 70,
                children: [
                    GradeTileNode(
                        title: "Halbjahr 1",
                        type: .calculation,
                        weightPercent: 50,
                        children: [
                            GradeTileNode(title: "Lange Klassenarbeit 1", type: .input, weightPercent: 60),
                            GradeTileNode(title: "Kurztest", type: .input, weightPercent: 40)
                        ]
                    ),
                    GradeTileNode(
                        title: "Halbjahr 2",
                        type: .calculation,
                        weightPercent: 50,
                        children: [
                            GradeTileNode(title: "Mündliche Mitarbeit", type: .input, weightPercent: 100)
                        ]
                    )
                ]
            ),
            GradeTileNode(
                title: "Projektphase",
                type: .calculation,
                weightPercent: 30,
                children: [
                    GradeTileNode(title: "Präsentation", type: .input, weightPercent: 50),
                    GradeTileNode(title: "Dokumentation", type: .input, weightPercent: 50)
                ]
            )
        ])

        return makeFixture(
            className: "Q1",
            subject: "Physik",
            schoolYear: "2025/2026",
            root: root
        )
    }

    private static func makeFixture(
        className: String,
        subject: String,
        schoolYear: String,
        root: GradeTileNode
    ) -> GradebookDetailPreviewFixture {
        let configuration = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: PersistenceController.schema, configurations: [configuration])
        let context = ModelContext(container)

        let schoolClass = SchoolClass(name: className, subject: subject, schoolYear: schoolYear)
        context.insert(schoolClass)

        let students: [Student] = [
            Student(firstName: "Anna", lastName: "Meyer", studentNumber: 1, classId: schoolClass.id),
            Student(firstName: "Ben", lastName: "Schulz", studentNumber: 2, classId: schoolClass.id),
            Student(firstName: "Clara", lastName: "Becker", studentNumber: 3, classId: schoolClass.id)
        ]
        for student in students {
            schoolClass.students.append(student)
        }

        let tab = GradebookTabEntity(
            title: schoolYear,
            sortOrder: 0,
            roundingDecimals: 2,
            schoolClass: schoolClass
        )
        context.insert(tab)

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        for student in students {
            let row = GradebookRowEntity(
                id: student.id,
                sortOrder: student.studentNumber - 1,
                tab: tab,
                student: student
            )
            context.insert(row)
        }

        try? context.save()

        let inputColumns = GradeTileTree.columns(from: root).filter { $0.type == .input }
        if let firstInput = inputColumns.first {
            GradebookRepository.upsertCellValue(
                rawValue: "2",
                rowID: students[0].id,
                nodeID: firstInput.nodeID,
                in: tab,
                context: context
            )
        }
        if inputColumns.count > 1 {
            GradebookRepository.upsertCellValue(
                rawValue: "3",
                rowID: students[1].id,
                nodeID: inputColumns[1].nodeID,
                in: tab,
                context: context
            )
        }

        return GradebookDetailPreviewFixture(
            container: container,
            context: context,
            schoolClass: schoolClass,
            tab: tab
        )
    }
}

private struct GradebookDetailPreviewHost: View {
    let fixture: GradebookDetailPreviewFixture
    let note: String

    var body: some View {
        NavigationStack {
            GradebookDetailView(
                schoolClass: fixture.schoolClass,
                tab: fixture.tab,
                context: fixture.context
            )
        }
        .overlay(alignment: .topLeading) {
            Text(note)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)
        }
        .modelContainer(fixture.container)
    }
}

#Preview("Technischer Root versteckt") {
    GradebookDetailPreviewHost(
        fixture: GradebookDetailPreviewFactory.makeMigratedRootFixture(),
        note: "Pruefe: technischer Root unsichtbar, 'Schuljahr' als erste sichtbare Ebene."
    )
}

#Preview("Top-Level-Breiten und Slots") {
    GradebookDetailPreviewHost(
        fixture: GradebookDetailPreviewFactory.makeMultipleTopLevelFixture(),
        note: "Pruefe: mehrere sichtbare Top-Level-Bloecke, Headerhoehe und Move-Slots im Live Preview."
    )
}
#endif
