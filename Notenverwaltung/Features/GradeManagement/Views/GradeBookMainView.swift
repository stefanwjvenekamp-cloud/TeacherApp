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
    @Query(sort: [SortDescriptor(\SchoolClass.name, order: .forward)]) private var classes: [SchoolClass]
    @State private var hasInitialized = false

    var body: some View {
        ZStack {
            Color.systemGroupedBackground
                .ignoresSafeArea()

            List {
                Section {
                ForEach(classes) { schoolClass in
                    NavigationLink {
                        ClassGradebooksDetailContainer(schoolClassID: schoolClass.id)
                    } label: {
                        ClassCard(
                            schoolClass: schoolClass,
                            studentCount: schoolClass.enrollments.filter(\.isActive).count
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                } header: {
                    header
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("TeacherApp")
        .adaptiveNavigationBarTitleDisplayMode(.large)
        .task {
            initializeIfNeeded()
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
        .padding(.top, 8)
        .textCase(nil)
    }

    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true

        if classes.isEmpty {
            MockSeedDataService.seedIfNeeded(context: modelContext)
        }

        let descriptor = FetchDescriptor<SchoolClass>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let currentClasses = (try? modelContext.fetch(descriptor)) ?? []
        for schoolClass in currentClasses {
            GradebookRepository.ensureDefaultTab(for: schoolClass, in: modelContext)
        }
    }
}

private struct ClassGradebooksDetailContainer: View {
    @Environment(\.modelContext) private var modelContext
    let schoolClassID: UUID

    var body: some View {
        if let schoolClass {
            ClassGradebooksDetailView(schoolClass: schoolClass)
        } else {
            ContentUnavailableView(
                "Klasse nicht verfügbar",
                systemImage: "exclamationmark.triangle",
                description: Text("Die ausgewählte Klasse konnte nicht geladen werden.")
            )
        }
    }

    private var schoolClass: SchoolClass? {
        let descriptor = FetchDescriptor<SchoolClass>(
            predicate: #Predicate { $0.id == schoolClassID }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }
}

#Preview("Klassen") {
    NavigationStack {
        GradeBookMainView()
    }
    .modelContainer(
        for: [
            SchoolClass.self,
            ClassEnrollment.self,
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
