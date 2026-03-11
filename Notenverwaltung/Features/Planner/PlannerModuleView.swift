import SwiftUI

struct PlannerModuleView: View {
    var body: some View {
        FeatureTemplateView(
            title: "Planung",
            icon: "checklist",
            iconColor: .Theme.skyBlue,
            subtitle: "Unterricht planen",
            description: "Modulstruktur vorbereitet. Dieses Modul nutzt später dieselben Klassen- und Kursdaten wie die Notenverwaltung."
        )
    }
}
