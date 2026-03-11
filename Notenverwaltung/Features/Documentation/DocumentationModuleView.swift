import SwiftUI

struct DocumentationModuleView: View {
    var body: some View {
        FeatureTemplateView(
            title: "Dokumentation",
            icon: "note.text",
            iconColor: .Theme.green,
            subtitle: "Schülernotizen und Beobachtungen",
            description: "Modulstruktur vorbereitet. Notizen werden später auf denselben Schülerstammdaten aufbauen."
        )
    }
}
