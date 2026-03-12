//
//  ClassSelectionView.swift
//  Notenverwaltung
//
//  Klassenübersicht + gekoppelter Kachelkopf/Tabelle
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct GradeBookMainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var classes: [SchoolClass] = []
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            Color.systemGroupedBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    LazyVStack(spacing: 16) {
                        ForEach(classes) { schoolClass in
                            NavigationLink {
                                ClassGradebooksDetailView(
                                    schoolClass: schoolClass
                                )
                            } label: {
                                ClassCard(
                                    schoolClass: schoolClass,
                                    studentCount: schoolClass.students.count
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("TeacherApp")
        .adaptiveNavigationBarTitleDisplayMode(.large)
        .task {
            loadDataIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deine Klassen")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("\(classes.count) \(classes.count == 1 ? "Klasse" : "Klassen")")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func loadDataIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true

        let existingClasses = fetchClasses()
        if existingClasses.isEmpty {
            MockSeedDataService.seedIfNeeded(context: modelContext)
        }

        classes = fetchClasses()

        // Ensure each class has at least one tab entity
        for schoolClass in classes {
            GradebookRepository.ensureDefaultTab(for: schoolClass, in: modelContext)
        }
    }

    private func fetchClasses() -> [SchoolClass] {
        let descriptor = FetchDescriptor<SchoolClass>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

#Preview("Klassen") {
    NavigationStack {
        GradeBookMainView()
    }
    .modelContainer(
        for: [
            SchoolClass.self,
            GradebookTabEntity.self,
            GradebookNodeEntity.self,
            GradebookRowEntity.self,
            GradebookCellValueEntity.self,
            Student.self,
            GradeEntry.self,
            Assessment.self,
            GradeComment.self,
            GradebookSnapshot.self
        ],
        inMemory: true
    )
}
