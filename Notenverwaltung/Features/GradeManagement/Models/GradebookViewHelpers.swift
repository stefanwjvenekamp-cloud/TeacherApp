import SwiftUI

// MARK: - View Helper Types

struct GradeInputCellTarget: Identifiable, Equatable {
    let rowID: UUID
    let nodeID: UUID

    var id: String {
        "\(rowID.uuidString)-\(nodeID.uuidString)"
    }
}

struct TileSettingsTarget: Identifiable {
    let id: UUID
}

/// Info about a single leaf column for width computation.
struct LeafColumnInfo {
    let nodeID: UUID
    let width: CGFloat
}

/// An insertion slot shown between siblings (or at the edges) when in move-mode.
struct InsertionSlot: Identifiable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let slotWidth: CGFloat
    let slotHeight: CGFloat
    let action: InsertionAction
    let isVertical: Bool
}

enum InsertionAction {
    case beforeSibling(UUID)
    case afterSibling(UUID)
    case appendToParent(UUID)
}

struct StudentInsertionSlot: Identifiable {
    let id: String
    let y: CGFloat
    let slotHeight: CGFloat
    let action: StudentInsertionAction
}

enum StudentInsertionAction {
    case beforeStudent(UUID)
    case afterStudent(UUID)
}

enum GradeInputCategory: String, CaseIterable, Identifiable {
    case numbers = "Zahlen"
    case text = "Text"
    case emojis = "Emojis"

    var id: String { rawValue }
}

struct EmojiOption: Identifiable {
    let id: String
    let emoji: String
    let symbol: String
    let label: String

    var token: String {
        "[emoji:\(id)]"
    }

    static func fromStoredValue(_ value: String) -> EmojiOption? {
        guard value.hasPrefix("[emoji:"), value.hasSuffix("]") else { return nil }
        let idStart = value.index(value.startIndex, offsetBy: 7)
        let id = String(value[idStart..<value.index(before: value.endIndex)])
        return catalog.first(where: { $0.id == id })
    }

    var primaryColor: Color {
        switch id {
        case "happy": return .yellow
        case "sad": return .gray
        case "greenCheck", "thumbsUp", "star", "trophy": return .green
        case "redCross", "thumbsDown", "warn", "minus": return .red
        case "clock", "absent", "excused", "homework": return .orange
        case "oral", "note", "idea", "eye": return .blue
        default: return .teal
        }
    }

    static let catalog: [EmojiOption] = [
        EmojiOption(id: "happy", emoji: "", symbol: "face.smiling.fill", label: "Zufrieden"),
        EmojiOption(id: "sad", emoji: "", symbol: "face.dashed", label: "Unzufrieden"),
        EmojiOption(id: "greenCheck", emoji: "", symbol: "checkmark.circle.fill", label: "Erledigt"),
        EmojiOption(id: "thumbsUp", emoji: "", symbol: "hand.thumbsup.fill", label: "Gut"),
        EmojiOption(id: "star", emoji: "", symbol: "star.fill", label: "Sehr gut"),
        EmojiOption(id: "trophy", emoji: "", symbol: "trophy.fill", label: "Ausgezeichnet"),
        EmojiOption(id: "redCross", emoji: "", symbol: "xmark.circle.fill", label: "Nicht erledigt"),
        EmojiOption(id: "thumbsDown", emoji: "", symbol: "hand.thumbsdown.fill", label: "Mangelhaft"),
        EmojiOption(id: "warn", emoji: "", symbol: "exclamationmark.triangle.fill", label: "Achtung"),
        EmojiOption(id: "minus", emoji: "", symbol: "minus.circle.fill", label: "Fehlend"),
        EmojiOption(id: "clock", emoji: "", symbol: "clock.fill", label: "Ausstehend"),
        EmojiOption(id: "absent", emoji: "", symbol: "person.slash.fill", label: "Abwesend"),
        EmojiOption(id: "excused", emoji: "", symbol: "envelope.fill", label: "Entschuldigt"),
        EmojiOption(id: "homework", emoji: "", symbol: "doc.text.fill", label: "Hausaufgabe"),
        EmojiOption(id: "oral", emoji: "", symbol: "bubble.left.fill", label: "Mündlich"),
        EmojiOption(id: "note", emoji: "", symbol: "pencil.circle.fill", label: "Notiz"),
        EmojiOption(id: "idea", emoji: "", symbol: "lightbulb.fill", label: "Idee"),
        EmojiOption(id: "eye", emoji: "", symbol: "eye.fill", label: "Beobachtung")
    ]
}

// MARK: - Preference Keys

struct GridHorizontalContentOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
