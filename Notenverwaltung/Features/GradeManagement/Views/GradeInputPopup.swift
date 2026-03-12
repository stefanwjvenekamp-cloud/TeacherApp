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

    var body: some View {
        VStack(spacing: 16) {
            header
            inputPreview
            categorySwitcher
            categoryContent
            actionRow
        }
        .padding(20)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isDraggingPopup ? 0.10 : 0.16), radius: isDraggingPopup ? 14 : 26, y: isDraggingPopup ? 6 : 14)
        .overlay {
            if showSignPicker {
                signPickerOverlay
            }
        }
        .offset(x: panelOffset.width + dragOffset.width, y: panelOffset.height + dragOffset.height)
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack {
                Text("Notenfeld bearbeiten")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(panelDragGesture)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var inputPreview: some View {
        HStack(spacing: 10) {
            if let option = EmojiOption.fromStoredValue(value) {
                Image(systemName: option.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(option.primaryColor, option.primaryColor.opacity(0.3))
            } else {
                Text(value.isEmpty ? "Eingabe..." : value)
                    .font(previewFont)
                    .foregroundStyle(value.isEmpty ? .secondary : .primary)
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
                Image(systemName: "delete.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var categorySwitcher: some View {
        HStack(spacing: 8) {
            ForEach(GradeInputCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedCategory == category ? Color.blue : Color.black.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch selectedCategory {
        case .numbers:
            VStack(spacing: 8) {
                ForEach(numberGrid, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { token in
                            Button {
                                handleNumberToken(token)
                            } label: {
                                Text(token)
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(Color.black.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case .text:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(textOptions, id: \.self) { option in
                    Button {
                        value = option
                    } label: {
                        Text(option)
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color.black.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .emojis:
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(emojiOptions) { option in
                        Button {
                            value = option.token
                        } label: {
                            Image(systemName: option.symbol)
                                .font(.system(size: 22, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(option.primaryColor, option.primaryColor.opacity(0.3))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                LinearGradient(
                                    colors: emojiCardColors(for: option),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                            }
                            .shadow(color: option.primaryColor.opacity(0.20), radius: 6, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private func emojiCardColors(for option: EmojiOption) -> [Color] {
        [option.primaryColor.opacity(0.18), option.primaryColor.opacity(0.06)]
    }

    private var previewFont: Font {
        .system(size: 24, weight: .semibold, design: .default)
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

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button("Leeren") {
                value = ""
            }
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.bordered)

            Spacer()

            Button("Übernehmen") {
                onCommit()
            }
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.borderedProminent)
        }
    }

    private var signPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.08)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onTapGesture {
                    showSignPicker = false
                }

            VStack(spacing: 10) {
                Text("Vorzeichen wählen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        value.append("+")
                        showSignPicker = false
                    } label: {
                        Text("+")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .frame(width: 64, height: 48)
                            .background(Color.black.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        value.append("-")
                        showSignPicker = false
                    } label: {
                        Text("-")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .frame(width: 64, height: 48)
                            .background(Color.black.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.15), radius: 14, y: 8)
            .frame(maxWidth: 220)
        }
        .padding(10)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    private func handleNumberToken(_ token: String) {
        if token == "+-" {
            showSignPicker = true
        } else {
            value.append(token)
        }
    }
}
