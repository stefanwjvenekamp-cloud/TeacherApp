import SwiftUI

struct GradeInputPopup: View {
    @Binding var value: String
    @Binding var selectedCategory: GradeInputCategory
    let onClose: () -> Void
    let onCommit: () -> Void

    private let numberGrid = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["+-", "0", ","]
    ]

    private let textOptions = ["fehlt", "mündlich", "Hausaufgabe", "entschuldigt", "nachreichen", "ok"]
    private let emojiOptions: [EmojiOption] = EmojiOption.catalog

    @State private var showSignPicker = false
    @State private var panelOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var isDraggingPopup = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(spacing: 14) {
                inputPreview
                categorySwitcher
                categoryContent
                actionRow
            }
            .padding(16)
        }
        .frame(width: 340)
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(isDraggingPopup ? 0.12 : 0.2),
                radius: isDraggingPopup ? 12 : 20,
                y: isDraggingPopup ? 4 : 8)
        .overlay {
            if showSignPicker {
                signPickerOverlay
            }
        }
        .offset(x: panelOffset.width + dragOffset.width,
                y: panelOffset.height + dragOffset.height)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            HStack {
                Text("Notenfeld bearbeiten")
                    .font(.system(size: 14, weight: .semibold))

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(panelDragGesture)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Input Preview

    private var inputPreview: some View {
        HStack(spacing: 10) {
            if let option = EmojiOption.fromStoredValue(value) {
                Image(systemName: option.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(option.primaryColor, option.primaryColor.opacity(0.3))
            } else {
                Text(value.isEmpty ? "Eingabe..." : value)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(value.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                if EmojiOption.fromStoredValue(value) != nil {
                    value = ""
                } else {
                    _ = value.popLast()
                }
            } label: {
                Image(systemName: "delete.left.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.systemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Category Switcher

    private var categorySwitcher: some View {
        Picker("Kategorie", selection: $selectedCategory) {
            ForEach(GradeInputCategory.allCases) { category in
                Text(category.rawValue).tag(category)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Category Content

    @ViewBuilder
    private var categoryContent: some View {
        switch selectedCategory {
        case .numbers:
            numberPad
        case .text:
            textGrid
        case .emojis:
            emojiGrid
        }
    }

    private var numberPad: some View {
        VStack(spacing: 6) {
            ForEach(numberGrid, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { token in
                        Button {
                            handleNumberToken(token)
                        } label: {
                            Text(token)
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(keyBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(KeyButtonStyle())
                    }
                }
            }
        }
    }

    private var textGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
            ForEach(textOptions, id: \.self) { option in
                Button {
                    value = option
                } label: {
                    Text(option)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(keyBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(KeyButtonStyle())
            }
        }
    }

    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(emojiOptions) { option in
                    Button {
                        value = option.token
                    } label: {
                        Image(systemName: option.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(option.primaryColor, option.primaryColor.opacity(0.3))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(option.primaryColor.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(KeyButtonStyle())
                }
            }
        }
        .frame(maxHeight: 200)
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) {
                value = ""
            } label: {
                Text("Leeren")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                onCommit()
            } label: {
                Text("Übernehmen")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Sign Picker Overlay

    private var signPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.001)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSignPicker = false
                    }
                }

            VStack(spacing: 12) {
                Text("Vorzeichen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 10) {
                    signButton("+")
                    signButton("-")
                }
            }
            .padding(16)
            .background(Color.secondarySystemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .frame(maxWidth: 180)
        }
        .padding(10)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func signButton(_ sign: String) -> some View {
        Button {
            value.append(sign)
            withAnimation(.easeOut(duration: 0.2)) {
                showSignPicker = false
            }
        } label: {
            Text(sign)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 44)
                .background(keyBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(KeyButtonStyle())
    }

    // MARK: - Helpers

    private var keyBackground: some View {
        Color.systemGroupedBackground
    }

    private var panelDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .updating($isDraggingPopup) { _, state, _ in
                state = true
            }
            .onEnded { value in
                panelOffset.width += value.translation.width
                panelOffset.height += value.translation.height
            }
    }

    private func handleNumberToken(_ token: String) {
        if token == "+-" {
            withAnimation(.easeOut(duration: 0.2)) {
                showSignPicker = true
            }
        } else {
            value.append(token)
        }
    }
}

// MARK: - Key Button Style

private struct KeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
