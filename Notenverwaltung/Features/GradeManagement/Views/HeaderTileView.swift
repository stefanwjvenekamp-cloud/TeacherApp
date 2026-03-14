import Foundation
import SwiftUI

struct HeaderTileView: View {
    let node: GradeTileNode
    let isRoot: Bool
    let level: Int
    let parentIsCalculation: Bool
    let width: CGFloat
    let height: CGFloat
    let colorFillWidth: CGFloat
    let tileColorStyle: GradeTileColorStyle
    let isLeaf: Bool
    let showWeightWarning: Bool
    let isMoving: Bool
    let gesturesEnabled: Bool

    let onWeightChange: (Double) -> Void
    let onAddInput: () -> Void
    let onAddCalculation: () -> Void
    let onAddSiblingArea: () -> Void
    let canMergeSiblings: Bool
    let onMergeSiblings: () -> Void
    let onOpenSettings: () -> Void
    let onAutoDistribute: () -> Void
    let onDelete: () -> Void
    let onTitleSubmit: (String) -> Void
    let onStartMove: () -> Void
    let dragProvider: () -> NSItemProvider
    
    @State private var showCustomWeightSheet = false
    @State private var showWeightPopover = false
    @State private var customWeightText = ""
    @State private var isEditing = false
    @State private var editingTitle = ""
    @FocusState private var isTitleFieldFocused: Bool

    private var leafCornerRadius: CGFloat {
        switch min(max(level, 0), 4) {
        case 0: return 12
        case 1: return 10
        case 2: return 8
        default: return 6
        }
    }

    var body: some View {
        Group {
            if isLeaf {
                leafContent
            } else {
                groupedContent
            }
        }
        .frame(width: width, height: height)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: isLeaf ? leafCornerRadius : 0, style: .continuous))
        .overlay {
            if isLeaf {
                RoundedRectangle(cornerRadius: leafCornerRadius, style: .continuous)
                    .strokeBorder(Color.Table.border.opacity(0.9), lineWidth: 0.8)
            }
        }
        .overlay {
            if isMoving {
                RoundedRectangle(cornerRadius: isLeaf ? leafCornerRadius : 4, style: .continuous)
                    .strokeBorder(Color.blue, lineWidth: 2.5)
            }
        }
        .background {
            if isMoving {
                RoundedRectangle(cornerRadius: isLeaf ? leafCornerRadius : 4, style: .continuous)
                    .fill(Color.blue.opacity(0.06))
                    .shadow(color: Color.blue.opacity(0.3), radius: 12, y: 4)
                    .scaleEffect(1.03)
            }
        }
        .opacity(isMoving ? 0.85 : 1.0)
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: isLeaf ? leafCornerRadius : 4, style: .continuous))
        .modifier(
            HeaderTileGestureModifier(
                gesturesEnabled: gesturesEnabled,
                isRoot: isRoot,
                dragProvider: dragProvider,
                onStartMove: onStartMove,
                onDelete: onDelete
            )
        )
        .sheet(isPresented: $showCustomWeightSheet) {
            NavigationStack {
                Form {
                    Section("Prozentwert") {
                        TextField("z. B. 33.33", text: $customWeightText)
                            .keyboardType(.decimalPad)
                    }
                }
                .navigationTitle("Eigene Eingabe")
                .adaptiveNavigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            showCustomWeightSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Übernehmen") {
                            let normalized = customWeightText.replacingOccurrences(of: ",", with: ".")
                            if let value = Double(normalized), value >= 0, value <= 100 {
                                onWeightChange(value)
                            }
                            showCustomWeightSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(220)])
        }
    }

    private var leafContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                leadingControls
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, leafControlTopPadding)
            .frame(height: leafControlRowHeight)

            centeredTitle
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, leafTitleHorizontalPadding)
                .padding(.top, leafTitleTopPadding)
                .padding(.bottom, leafTitleBottomPadding)

            Spacer(minLength: leafBottomSpacing)
        }
    }

    private var groupedContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                leadingControls
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, groupedControlTopPadding)
            .frame(height: groupedControlRowHeight)

            centeredTitle
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, groupedTitleHorizontalPadding)
                .padding(.top, groupedTitleTopPadding)
                .padding(.bottom, groupedTitleBottomPadding)

            if height > groupedControlRowHeight {
                Spacer(minLength: 0)
            }
        }
    }

    private func commitTitleEdit() {
        onTitleSubmit(editingTitle)
        isEditing = false
        isTitleFieldFocused = false
    }

    @ViewBuilder
    private var centeredTitle: some View {
        Group {
            if isEditing {
                TextField("", text: $editingTitle)
                    .font(titleFont)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color.Table.textPrimary)
                    .lineLimit(1)
                    .focused($isTitleFieldFocused)
                    .onSubmit(commitTitleEdit)
                    .onChange(of: isTitleFieldFocused) { _, isFocused in
                        if !isFocused && isEditing {
                            commitTitleEdit()
                        }
                    }
            } else {
                Text(node.title)
                    .font(titleFont)
                    .foregroundStyle(Color.Table.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .onTapGesture(count: 2) {
                        editingTitle = node.title
                        isEditing = true
                        isTitleFieldFocused = true
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, effectiveTitleHorizontalPadding)
    }

    @ViewBuilder
    private var leadingControls: some View {
        HStack(spacing: 6) {
            if !isRoot {
                Button {
                    onStartMove()
                } label: {
                    Image(systemName: isMoving ? "arrow.up.and.down.and.arrow.left.and.right" : "line.3.horizontal")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isMoving ? Color.blue : Color.Table.textSecondary.opacity(0.6))
                        .frame(width: 24, height: 26)
                        .background(isMoving ? Color.blue.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if parentIsCalculation {
                Button {
                    showWeightPopover = true
                } label: {
                    HStack(spacing: 3) {
                        Text(weightLabel(node.weightPercent))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showWeightPopover) {
                    WeightPickerPopover(
                        currentWeight: node.weightPercent,
                        onSelect: { value in
                            onWeightChange(value)
                            showWeightPopover = false
                        },
                        onCustomInput: {
                            showWeightPopover = false
                            customWeightText = String(format: "%.2f", node.weightPercent)
                                .replacingOccurrences(of: ".00", with: "")
                            showCustomWeightSheet = true
                        }
                    )
                }
            }

            if node.type == .calculation {
                Menu {
                    if !isRoot {
                        Button {
                            onAddSiblingArea()
                        } label: {
                            Label("Bereich gleiche Ebene", systemImage: "folder.badge.plus")
                        }
                    }
                    Button {
                        onAddCalculation()
                    } label: {
                        Label("Bereich Ebene darunter", systemImage: "folder")
                    }
                    if canMergeSiblings {
                        Button {
                            onMergeSiblings()
                        } label: {
                            Label("Zusammenführen", systemImage: "arrow.triangle.merge")
                        }
                    }
                    Divider()
                    Button {
                        onAddInput()
                    } label: {
                        Label("Notenspalte", systemImage: "tablecells")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.Table.textSecondary)
                        .padding(5)
                        .background(Color.Table.hover)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.Table.border, lineWidth: 0.8)
                        }
                }

                if showWeightWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
            }

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Table.textSecondary)
                    .padding(5)
                    .background(Color.Table.hover)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.Table.border, lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var titleHorizontalPadding: CGFloat {
        isLeaf ? 10 : 12
    }

    private var leafControlTopPadding: CGFloat {
        leafIsCompact ? 6 : min(max(height * 0.08, 8), 14)
    }

    private var leafControlRowHeight: CGFloat {
        leafIsCompact ? 24 : min(max(height * 0.24, 28), 40)
    }

    private var leafTitleHorizontalPadding: CGFloat {
        leafIsCompact ? min(max(width * 0.09, 10), 16) : min(max(width * 0.11, 12), 20)
    }

    private var leafTitleTopPadding: CGFloat {
        leafIsCompact ? 6 : min(max(height * 0.08, 7), 14)
    }

    private var leafTitleBottomPadding: CGFloat {
        leafIsCompact ? 6 : min(max(height * 0.10, 8), 16)
    }

    private var leafBottomSpacing: CGFloat {
        leafIsCompact ? 4 : min(max(height * 0.08, 6), 14)
    }

    private var groupedControlTopPadding: CGFloat {
        min(max(height * 0.10, 8), 14)
    }

    private var groupedControlRowHeight: CGFloat {
        min(max(height * 0.32, 28), 42)
    }

    private var groupedTitleHorizontalPadding: CGFloat {
        min(max(width * 0.08, 12), 20)
    }

    private var groupedTitleTopPadding: CGFloat {
        min(max(height * 0.08, 6), 12)
    }

    private var groupedTitleBottomPadding: CGFloat {
        min(max(height * 0.12, 8), 16)
    }

    private var leafIsCompact: Bool {
        height <= 56
    }

    private var effectiveTitleHorizontalPadding: CGFloat {
        let maxAllowedPaddingPerSide = max((width - 32) / 2, 0)
        return min(titleHorizontalPadding, maxAllowedPaddingPerSide)
    }

    private var leadingReservedWidth: CGFloat {
        var width: CGFloat = 0

        if !isRoot {
            width += 24 + 8
        }

        if parentIsCalculation {
            width += 8 + 54
        }

        if node.type == .calculation {
            width += 8 + 28
            if showWeightWarning {
                width += 8 + 14
            }
        }

        return width
    }

    @ViewBuilder
    private var tileBackground: some View {
        let baseBackground = automaticBackground
        if tileColorStyle == .automatic {
            baseBackground
        } else {
            ZStack(alignment: .leading) {
                baseBackground
                tileColor
                    .frame(width: min(max(colorFillWidth, 0), width))
            }
        }
    }

    private var automaticBackground: Color {
        let normalizedLevel = min(max(level, 0), 4)
        if node.type == .calculation {
            switch normalizedLevel {
            case 0:
                return Color.Table.headerBackground
            case 1:
                return Color.Table.headerBackground.opacity(0.75)
            case 2:
                return Color.Table.headerBackground.opacity(0.55)
            default:
                return Color.Table.headerBackground.opacity(0.40)
            }
        } else {
            switch normalizedLevel {
            case 0:
                return Color.Table.cellBackground
            case 1:
                return Color.Table.cellBackground.opacity(0.95)
            default:
                return Color.Table.cellBackground.opacity(0.90)
            }
        }
    }

    private var tileColor: Color {
        switch tileColorStyle {
        case .automatic:
            return automaticBackground
        case .slate:
            return Color(red: 0.92, green: 0.93, blue: 0.95)
        case .blue:
            return Color(red: 0.88, green: 0.93, blue: 0.99)
        case .green:
            return Color(red: 0.89, green: 0.96, blue: 0.91)
        case .orange:
            return Color(red: 0.99, green: 0.93, blue: 0.86)
        case .red:
            return Color(red: 0.99, green: 0.90, blue: 0.90)
        }
    }

    private var titleFont: Font {
        if isLeaf {
            let size = leafIsCompact
                ? min(max(height * 0.20, 12), 13.5)
                : min(max(height * 0.17, 13), 16)
            return .system(size: size, weight: .semibold)
        }

        let normalizedLevel = min(max(level, 0), 3)
        switch normalizedLevel {
        case 0:
            return .system(size: 15, weight: .bold)
        case 1:
            return .system(size: 14, weight: .semibold)
        default:
            return .system(size: 13, weight: .medium)
        }
    }

    private func weightLabel(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))%"
        }
        return String(format: "%.2f%%", value)
    }
}
struct HeaderTileGestureModifier: ViewModifier {
    let gesturesEnabled: Bool
    let isRoot: Bool
    let dragProvider: () -> NSItemProvider
    let onStartMove: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        if gesturesEnabled {
            content
                .onDrag {
                    dragProvider()
                }
                .contextMenu {
                    if !isRoot {
                        Button {
                            onStartMove()
                        } label: {
                            Label("Verschieben", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                        }
                    }
                    if !isRoot {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Weight Picker Popover
struct WeightPickerPopover: View {
    let currentWeight: Double
    let onSelect: (Double) -> Void
    let onCustomInput: () -> Void

    private let presetWeights: [Double] = [0, 10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 100]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Gewichtung")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatWeight(currentWeight))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 12)

            // Preset grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(presetWeights, id: \.self) { weight in
                    let isSelected = abs(currentWeight - weight) < 0.01
                    Button {
                        onSelect(weight)
                    } label: {
                        Text("\(Int(weight))%")
                            .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // Custom input row
            Button {
                onCustomInput()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Eigene Eingabe…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 250)
        .background(Color(.systemBackground))
    }

    private func formatWeight(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))%"
        }
        return String(format: "%.2f%%", value)
    }
}


