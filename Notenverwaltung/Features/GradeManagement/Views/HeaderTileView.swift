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

    let onWeightChange: (Double) -> Void
    let onAddInput: () -> Void
    let onAddCalculation: () -> Void
    let onAddSiblingArea: () -> Void
    let onOpenSettings: () -> Void
    let onAutoDistribute: () -> Void
    let onDelete: () -> Void
    let onTitleSubmit: (String) -> Void
    let onStartMove: () -> Void
    
    @State private var showCustomWeightSheet = false
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
        VStack(spacing: 0) {
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
                    .layoutPriority(1)
                }

                if isEditing {
                    TextField("", text: $editingTitle)
                        .font(titleFont)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.Table.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
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
                        .fixedSize(horizontal: true, vertical: false)
                        .onTapGesture(count: 2) {
                            editingTitle = node.title
                            isEditing = true
                            isTitleFieldFocused = true
                        }
                }

                if parentIsCalculation {
                    Menu {
                        ForEach(WeightOption.availableWeights) { option in
                            Button(option.label) {
                                onWeightChange(option.value)
                            }
                        }
                        Divider()
                        Button("Eigene Eingabe…") {
                            customWeightText = String(format: "%.2f", node.weightPercent).replacingOccurrences(of: ".00", with: "")
                            showCustomWeightSheet = true
                        }
                    } label: {
                        Text(weightLabel(node.weightPercent))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.Table.border, lineWidth: 0.8)
                            }
                    }
                    .layoutPriority(1)
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
                    .layoutPriority(1)

                    if showWeightWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                            .layoutPriority(1)
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
                .layoutPriority(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .frame(height: min(height, 38))

            if height > 38 {
                Spacer(minLength: 0)
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
        .contextMenu {
            if !isRoot {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                guard !isRoot else { return }
                onDelete()
            }
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

    private func commitTitleEdit() {
        onTitleSubmit(editingTitle)
        isEditing = false
        isTitleFieldFocused = false
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
        let normalizedLevel = min(max(level, 0), 3)
        switch normalizedLevel {
        case 0:
            return .system(size: 13, weight: .bold)
        case 1:
            return .system(size: 13, weight: .semibold)
        default:
            return .system(size: 12, weight: .medium)
        }
    }

    private func weightLabel(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))%"
        }
        return String(format: "%.2f%%", value)
    }
}
