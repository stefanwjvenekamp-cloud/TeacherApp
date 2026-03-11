import SwiftUI

enum TeacherSuiteModule: String, Hashable, CaseIterable, Identifiable {
    case gradeManagement
    case calendar
    case planner
    case groupAssignment
    case documentation
    case surveys

    var id: String { rawValue }
}

struct TeacherSuiteModuleDescriptor: Identifiable {
    let id: TeacherSuiteModule
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color

    static let all: [TeacherSuiteModuleDescriptor] = [
        TeacherSuiteModuleDescriptor(
            id: .gradeManagement,
            title: "Notenverwaltung",
            subtitle: "Noten erfassen und auswerten",
            icon: "list.clipboard.fill",
            accentColor: .Theme.primaryBlue
        ),
        TeacherSuiteModuleDescriptor(
            id: .calendar,
            title: "Kalender",
            subtitle: "Termine und Ereignisse",
            icon: "calendar",
            accentColor: .Theme.red
        ),
        TeacherSuiteModuleDescriptor(
            id: .planner,
            title: "Planung",
            subtitle: "Unterricht vorbereiten",
            icon: "checklist",
            accentColor: .Theme.skyBlue
        ),
        TeacherSuiteModuleDescriptor(
            id: .groupAssignment,
            title: "Gruppeneinteilung",
            subtitle: "Gruppen und Teams organisieren",
            icon: "person.3.fill",
            accentColor: .Theme.teal
        ),
        TeacherSuiteModuleDescriptor(
            id: .documentation,
            title: "Dokumentation",
            subtitle: "Schülernotizen und Beobachtungen",
            icon: "note.text",
            accentColor: .Theme.green
        ),
        TeacherSuiteModuleDescriptor(
            id: .surveys,
            title: "Umfragen",
            subtitle: "Befragungen erstellen und auswerten",
            icon: "chart.bar.doc.horizontal.fill",
            accentColor: .Theme.purple
        )
    ]
}
