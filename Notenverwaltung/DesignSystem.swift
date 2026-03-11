//
//  DesignSystem.swift
//  Notenverwaltung
//
//  Zentrales Design System mit Konstanten, Farben und wiederverwendbaren Komponenten
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design Constants

enum DesignConstants {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
    }
    
    enum IconSize {
        static let small: CGFloat = 16
        static let medium: CGFloat = 20
        static let large: CGFloat = 36
        static let xlarge: CGFloat = 56
    }
    
    enum FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 14
        static let callout: CGFloat = 16
        static let subheadline: CGFloat = 17
        static let headline: CGFloat = 18
        static let title3: CGFloat = 20
        static let title2: CGFloat = 28
        static let title1: CGFloat = 32
        static let largeTitle: CGFloat = 42
    }
}

// MARK: - App Colors

extension Color {
    // System colors mit Fallback für nicht-iOS Plattformen
    static var systemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground)
        #else
        Color(red: 0.95, green: 0.95, blue: 0.97)
        #endif
    }
    
    static var secondarySystemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        .white
        #endif
    }
    
    static var tertiarySystemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.tertiarySystemGroupedBackground)
        #else
        Color(red: 0.98, green: 0.98, blue: 0.99)
        #endif
    }
    
    // App Theme Colors - zentral definiert
    enum Theme {
        static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 0.89)
        static let lightBlue = Color(red: 0.2, green: 0.6, blue: 0.95)
        static let green = Color(red: 0.20, green: 0.78, blue: 0.35)
        static let purple = Color(red: 0.69, green: 0.32, blue: 0.87)
        static let red = Color(red: 0.90, green: 0.20, blue: 0.33)
        static let skyBlue = Color(red: 0.35, green: 0.65, blue: 0.90)
        static let teal = Color(red: 0.20, green: 0.69, blue: 0.67)
        
        static let emptyStateGradientStart = Color(red: 0.95, green: 0.97, blue: 1.0)
        
        static func gradient(from: Color, to: Color) -> LinearGradient {
            LinearGradient(colors: [from, to], startPoint: .leading, endPoint: .trailing)
        }
    }

    // Tabellen-Farbpalette
    enum Table {
        /// Zellhintergrund – #FFFFFF
        static let cellBackground = Color.white
        /// Header-Hintergrund – #E8ECF1
        static let headerBackground = Color(red: 0.91, green: 0.925, blue: 0.945)
        /// Linienfarbe – #E2E8F0
        static let border = Color(red: 0.886, green: 0.910, blue: 0.941)
        /// Stärkere Containerrahmen – #C4CDD9
        static let containerBorder = Color(red: 0.77, green: 0.80, blue: 0.85)
        /// Primärer Text – #0F172A
        static let textPrimary = Color(red: 0.059, green: 0.090, blue: 0.165)
        /// Sekundärer Text – #64748B
        static let textSecondary = Color(red: 0.392, green: 0.455, blue: 0.545)
        /// Hover / ausgewählte Zeile – #F1F5F9
        static let hover = Color(red: 0.945, green: 0.961, blue: 0.976)
    }
}

// MARK: - View Extensions

extension View {
    /// Plattform-spezifische Navigation Bar Title Display Mode
    @ViewBuilder
    func adaptiveNavigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View {
        #if os(iOS)
        switch mode {
        case .inline:
            navigationBarTitleDisplayMode(.inline)
        case .large:
            navigationBarTitleDisplayMode(.large)
        case .automatic:
            navigationBarTitleDisplayMode(.automatic)
        }
        #else
        self
        #endif
    }
    
    /// Plattform-spezifischer List Style
    @ViewBuilder
    func adaptiveListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        self
        #endif
    }
    
    /// Standard Card Style für die App
    func cardStyle(cornerRadius: CGFloat = DesignConstants.CornerRadius.large) -> some View {
        self
            .background(Color.secondarySystemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Navigation Bar Title Display Mode

enum NavigationBarTitleDisplayMode {
    case inline, large, automatic
}

// MARK: - Reusable Components

/// Wiederverwendbarer Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    
    init(scale: CGFloat = 0.95) {
        self.scale = scale
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Wiederverwendbarer Badge
struct BadgeView: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.system(size: DesignConstants.FontSize.caption, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignConstants.Spacing.sm)
            .padding(.vertical, DesignConstants.Spacing.xs)
            .background(
                Capsule()
                    .fill(.red)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            )
    }
}

/// Empty State View für einheitliche Darstellung
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    init(
        icon: String,
        title: String,
        description: String,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionLabel = actionLabel
        self.action = action
    }
    
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(description)
        } actions: {
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Performance Optimierungen

/// Lazy Loading Image für bessere Performance
struct LazyImage: View {
    let systemName: String
    let size: CGFloat
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .drawingGroup() // Performance-Optimierung für komplexe Grafiken
    }
}
