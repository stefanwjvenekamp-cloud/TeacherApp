import SwiftUI

struct FloatingTileSettingsPanel: View {
    let node: GradeTileNode
    @Binding var columnWidth: CGFloat
    let showColumnWidthSlider: Bool
    let minColumnWidth: CGFloat
    let maxColumnWidth: CGFloat
    let onSave: (String, GradeTileColorStyle) -> Void
    let onAutoDistribute: () -> Void
    let onClose: () -> Void

    @State private var titleText: String
    @State private var colorStyle: GradeTileColorStyle
    @State private var panelOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var isDraggingPanel = false

    init(
        node: GradeTileNode,
        columnWidth: Binding<CGFloat>,
        showColumnWidthSlider: Bool,
        minColumnWidth: CGFloat,
        maxColumnWidth: CGFloat,
        onSave: @escaping (String, GradeTileColorStyle) -> Void,
        onAutoDistribute: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.node = node
        self._columnWidth = columnWidth
        self.showColumnWidthSlider = showColumnWidthSlider
        self.minColumnWidth = minColumnWidth
        self.maxColumnWidth = maxColumnWidth
        self.onSave = onSave
        self.onAutoDistribute = onAutoDistribute
        self.onClose = onClose
        _titleText = State(initialValue: node.title)
        _colorStyle = State(initialValue: node.colorStyle)
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionView(title: "Titel") {
                        TextField("Titel", text: $titleText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                onSave(titleText, colorStyle)
                            }
                    }
                    
                    if showColumnWidthSlider {
                        sectionView(title: "Spaltenbreite") {
                            HStack {
                                Text("\(Int(columnWidth)) pt")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                                Slider(value: $columnWidth, in: minColumnWidth...maxColumnWidth, step: 5)
                            }
                        }
                    }
                    
                    sectionView(title: "Farbe") {
                        HStack(spacing: 8) {
                            ForEach(GradeTileColorStyle.allCases, id: \.self) { style in
                                Button {
                                    colorStyle = style
                                    onSave(titleText, colorStyle)
                                } label: {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(colorPreview(for: style))
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if colorStyle == style {
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .strokeBorder(Color.blue, lineWidth: 2.5)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    if node.type == .calculation && !node.children.isEmpty {
                        sectionView(title: "Gewichtung") {
                            Button {
                                onAutoDistribute()
                            } label: {
                                Text("Gleichverteilen")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Button {
                        onSave(titleText, colorStyle)
                        onClose()
                    } label: {
                        Text("Sichern & Schließen")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 420)
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(isDraggingPanel ? 0.12 : 0.2), radius: isDraggingPanel ? 12 : 20, y: isDraggingPanel ? 4 : 8)
        .offset(x: panelOffset.width + dragOffset.width,
                y: panelOffset.height + dragOffset.height)
    }
    
    private var dragHandle: some View {
        HStack(spacing: 12) {
            HStack {
                Text("Einstellungen")
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(panelDragGesture)

            Button {
                onSave(titleText, colorStyle)
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondarySystemGroupedBackground)
    }
    
    private var panelDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .updating($isDraggingPanel) { _, state, _ in
                state = true
            }
            .onEnded { value in
                panelOffset.width += value.translation.width
                panelOffset.height += value.translation.height
            }
    }

    private func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func colorPreview(for style: GradeTileColorStyle) -> Color {
        switch style {
        case .automatic:
            return node.type == .calculation ? Color(white: 0.965) : Color(white: 0.975)
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
}
