//
//  FeatureViews.swift
//  Notenverwaltung
//
//  Placeholder-Views für zukünftige Features
//

import SwiftUI

// MARK: - Feature Card Component

struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.lg) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(iconColor)
                
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                    Text(title)
                        .font(.title3.bold())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .cardStyle()
        .padding(.horizontal)
    }
}

// MARK: - Feature Template View

struct FeatureTemplateView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let subtitle: String
    let description: String
    
    var body: some View {
        ZStack {
            Color.systemGroupedBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DesignConstants.Spacing.xl) {
                    FeatureCard(
                        icon: icon,
                        iconColor: iconColor,
                        title: title,
                        subtitle: subtitle,
                        description: description
                    )
                }
                .padding(.top)
            }
        }
        .navigationTitle(title)
        .adaptiveNavigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feature Views

struct SerienbriefView: View {
    var body: some View {
        FeatureTemplateView(
            title: "Serienbrief",
            icon: "envelope.badge",
            iconColor: .Theme.green,
            subtitle: "Erstelle personalisierte Briefe",
            description: "Erstelle und versende Serienbriefe mit personalisierten Inhalten. Coming soon!"
        )
    }
}

struct UmfrageView: View {
    var body: some View {
        FeatureTemplateView(
            title: "Umfrage",
            icon: "chart.bar.doc.horizontal",
            iconColor: .Theme.purple,
            subtitle: "Erstelle und analysiere Umfragen",
            description: "Erstelle Umfragen und werte die Ergebnisse aus. Kommt bald!"
        )
    }
}

struct GruppentoolsView: View {
    var body: some View {
        FeatureTemplateView(
            title: "Gruppentools",
            icon: "person.3",
            iconColor: .Theme.teal,
            subtitle: "Verwalte Teams und Gruppen",
            description: "Organisiere deine Gruppen und Teams effizient. In Entwicklung."
        )
    }
}

struct GirocodeView: View {
    var body: some View {
        FeatureTemplateView(
            title: "Girocode",
            icon: "qrcode",
            iconColor: .orange,
            subtitle: "QR-Codes für Überweisungen",
            description: "Generiere GiroCodes für einfache Überweisungen. Feature wird bald verfügbar sein."
        )
    }
}
