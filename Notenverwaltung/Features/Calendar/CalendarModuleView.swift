import SwiftUI

struct CalendarModuleView: View {
    var body: some View {
        FeatureTemplateView(
            title: "Kalender",
            icon: "calendar",
            iconColor: .Theme.red,
            subtitle: "Termine und Ereignisse",
            description: "Modulstruktur vorbereitet. Hier werden zentrale Termine aus allen Modulen zusammengeführt."
        )
    }
}
