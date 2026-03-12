//
//  ContentView.swift
//  Notenverwaltung
//
//  Created by Stefan Venekamp on 08.03.26.
//

import SwiftUI
import SwiftData

// MARK: - Main Content View

struct ContentView: View {
    var body: some View {
        TabView {
            ÜbersichtView()
                .tabItem {
                    Label("Übersicht", systemImage: "square.grid.2x2")
                }
            
            NotenView()
                .tabItem {
                    Label("Noten", systemImage: "list.clipboard")
                }
            
            BriefeView()
                .tabItem {
                    Label("Briefe", systemImage: "envelope")
                }
            
            KalenderView()
                .tabItem {
                    Label("Kalender", systemImage: "calendar")
                }
            
            PlanungView()
                .tabItem {
                    Label("Planung", systemImage: "checklist")
                }
        }
    }
}

// MARK: - Dashboard Overview

struct ÜbersichtView: View {
    // iPad-optimiertes Layout: 3 Spalten
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: DesignConstants.Spacing.xl),
        count: 3
    )
    @State private var navigationPath: [TeacherSuiteModule] = []
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.systemGroupedBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignConstants.Spacing.xxl) {
                        DashboardHeader()
                            .padding(.horizontal, DesignConstants.Spacing.xxxl)
                            .padding(.top, DesignConstants.Spacing.xl)
                        
                        LazyVGrid(columns: columns, spacing: DesignConstants.Spacing.xl) {
                            ForEach(TeacherSuiteModuleDescriptor.all) { module in
                                ModuleTile(module: module) {
                                    navigationPath.append(module.id)
                                }
                            }
                        }
                        .padding(.horizontal, DesignConstants.Spacing.xxxl)
                        .padding(.bottom, DesignConstants.Spacing.xxxl)
                    }
                }
            }
            .adaptiveNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: Einstellungen implementieren
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: DesignConstants.IconSize.medium, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                #endif
            }
            .navigationDestination(for: TeacherSuiteModule.self) { module in
                destinationView(for: module)
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for module: TeacherSuiteModule) -> some View {
        switch module {
        case .gradeManagement:
            GradeBookMainView()
        case .calendar:
            CalendarModuleView()
        case .planner:
            PlannerModuleView()
        case .groupAssignment:
            GroupAssignmentModuleView()
        case .documentation:
            DocumentationModuleView()
        case .surveys:
            SurveyModuleView()
        }
    }
}

// MARK: - Dashboard Components

struct DashboardHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Dashboard")
                .font(.system(size: DesignConstants.FontSize.largeTitle, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("Alle Tools im Überblick")
                .font(.system(size: DesignConstants.FontSize.headline))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ModuleTile: View {
    let module: TeacherSuiteModuleDescriptor
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                iconSection
                infoSection
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.xlarge, style: .continuous))
            .shadow(
                color: module.accentColor.opacity(0.12),
                radius: 16,
                y: 8
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var iconSection: some View {
        ZStack {
            LinearGradient(
                colors: [module.accentColor, module.accentColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            LazyImage(systemName: module.icon, size: DesignConstants.IconSize.xlarge)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            
        }
        .frame(height: 160)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text(module.title)
                .font(.system(size: DesignConstants.FontSize.title3, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Text(module.subtitle)
                .font(.system(size: DesignConstants.FontSize.callout))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, DesignConstants.Spacing.xl)
        .background(Color.secondarySystemGroupedBackground)
    }
}

// MARK: - Tab Views

struct NotenView: View {
    var body: some View {
        NavigationStack {
            GradeBookMainView()
        }
    }
}

struct BriefeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.systemGroupedBackground
                    .ignoresSafeArea()
                
                ContentUnavailableView {
                    Label("Keine Briefe", systemImage: "envelope")
                } description: {
                    Text("Hier erscheinen deine Serienbriefe")
                }
            }
            .navigationTitle("Briefe")
        }
    }
}

struct KalenderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.systemGroupedBackground
                    .ignoresSafeArea()
                
                ContentUnavailableView {
                    Label("Kein Termin", systemImage: "calendar")
                } description: {
                    Text("Deine Termine erscheinen hier")
                }
            }
            .navigationTitle("Kalender")
        }
    }
}

struct PlanungView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.systemGroupedBackground
                    .ignoresSafeArea()
                
                ContentUnavailableView {
                    Label("Keine Planung", systemImage: "checklist")
                } description: {
                    Text("Erstelle deine erste Planung")
                }
            }
            .navigationTitle("Planung")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SchoolClass.self, Student.self, GradeEntry.self, Assessment.self, GradeComment.self, GradebookSnapshot.self], inMemory: true)
}
#Preview("Übersicht") {
    ÜbersichtView()
        .modelContainer(for: [SchoolClass.self, Student.self, GradeEntry.self, Assessment.self, GradeComment.self, GradebookSnapshot.self], inMemory: true)
}
