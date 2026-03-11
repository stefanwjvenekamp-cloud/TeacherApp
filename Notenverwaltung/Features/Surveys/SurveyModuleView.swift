import SwiftUI

struct SurveyModuleView: View {
    var body: some View {
        FeatureTemplateView(
            title: "Umfragen",
            icon: "chart.bar.doc.horizontal",
            iconColor: .Theme.purple,
            subtitle: "Befragungen erstellen und auswerten",
            description: "Modulstruktur vorbereitet. Ergebnisse können später klassen- und kursbezogen ausgewertet werden."
        )
    }
}
