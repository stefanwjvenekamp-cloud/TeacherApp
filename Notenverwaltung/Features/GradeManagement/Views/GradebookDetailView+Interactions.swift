import SwiftUI
import SwiftData

extension GradebookDetailView {
    // MARK: - Body

    @ViewBuilder
    var gradebookDetailContent: some View {
        @Bindable var vm = viewModel
        ZStack(alignment: .topLeading) {
            Color.systemGroupedBackground
                .ignoresSafeArea()

            zoomableTableLayout
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.Table.cellBackground)
        }
        .navigationTitle("\(schoolClass.name) – \(schoolClass.subject)")
        .adaptiveNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Neu") {
                    viewModel.showNewDialog = true
                }
            }
            #endif
        }
        .confirmationDialog("Neue Struktur", isPresented: $vm.showNewDialog, titleVisibility: .visible) {
            Button("Standardstruktur") {
                viewModel.replaceRootAndSyncRows(GradeTileTree.standardRoot())
            }
            Button("Manuell") {
                viewModel.replaceRootAndSyncRows(GradeTileTree.emptyRoot())
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Wähle, ob mit der Standardstruktur gestartet wird oder mit einer leeren Struktur.")
        }
        .confirmationDialog("Reiter löschen?", isPresented: $vm.showDeleteNodeDialog, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                guard let nodeID = viewModel.pendingDeleteNodeID else { return }
                viewModel.deleteNode(id: nodeID)
                viewModel.pendingDeleteNodeID = nil
            }
            Button("Abbrechen", role: .cancel) {
                viewModel.pendingDeleteNodeID = nil
            }
        } message: {
            Text("Dieser Reiter wird dauerhaft gelöscht.")
        }
        .modifier(
            SelectedNodeActionsDialogModifier(
                activeNodeID: Binding(
                    get: { activeSelectedNodeActionsID },
                    set: { activeSelectedNodeActionsID = $0 }
                ),
                movingNodeID: Binding(
                    get: { viewModel.movingNodeID },
                    set: { viewModel.movingNodeID = $0 }
                ),
                onDelete: { nodeID in
                    requestDeleteNode(for: nodeID)
                }
            )
        )
        .confirmationDialog("Schüler löschen?", isPresented: $vm.showDeleteStudentDialog, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                guard let studentID = viewModel.pendingDeleteStudentID else { return }
                viewModel.deleteStudent(id: studentID)
                viewModel.pendingDeleteStudentID = nil
            }
            Button("Abbrechen", role: .cancel) {
                viewModel.pendingDeleteStudentID = nil
            }
        } message: {
            Text("Alle Noten dieses Schülers werden entfernt.")
        }
        .confirmationDialog("Note löschen?", isPresented: $vm.showClearCellDialog, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                guard let target = viewModel.pendingClearCell else { return }
                viewModel.setInputValue("", rowID: target.rowID, nodeID: target.nodeID)
                viewModel.pendingClearCell = nil
            }
            Button("Abbrechen", role: .cancel) {
                viewModel.pendingClearCell = nil
            }
        } message: {
            Text("Dieser Eintrag wird gelöscht.")
        }
        .overlay(alignment: .top) {
            if viewModel.showAddStudentSheet {
                AddStudentTopPopup(
                    name: $vm.addStudentNameDraft,
                    onCancel: {
                        viewModel.showAddStudentSheet = false
                    },
                    onAdd: {
                        viewModel.addStudent(named: viewModel.addStudentNameDraft)
                        viewModel.addStudentNameDraft = ""
                        viewModel.showAddStudentSheet = false
                    }
                )
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if let target = viewModel.settingsTarget,
               let node = GradeTileTree.findNode(in: viewModel.root, id: target.id) {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.settingsTarget = nil
                        }
                    }
                
                FloatingTileSettingsPanel(
                    node: node,
                    columnWidth: Binding(
                        get: { width(for: target.id) },
                        set: { viewModel.columnWidths[target.id] = $0 }
                    ),
                    showColumnWidthSlider: node.showsAsColumn,
                    minColumnWidth: minColumnWidth,
                    maxColumnWidth: maxColumnWidth,
                    onSave: { title, colorStyle in
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedTitle.isEmpty {
                            viewModel.updateNodeTitle(nodeID: target.id, newTitle: trimmedTitle)
                        }
                        viewModel.updateNodeColorStyle(nodeID: target.id, colorStyle: colorStyle)
                    },
                    onAutoDistribute: {
                        viewModel.autoDistributeWeights(for: target.id)
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.settingsTarget = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .overlay {
            if let target = viewModel.activeInputCell {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.activeInputCell = nil
                    }

                GradeInputPopup(
                    value: $vm.inputPopupDraft,
                    selectedCategory: $vm.inputPopupCategory,
                    onClose: {
                        viewModel.activeInputCell = nil
                    },
                    onCommit: {
                        viewModel.setInputValue(viewModel.inputPopupDraft, rowID: target.rowID, nodeID: target.nodeID)
                        viewModel.activeInputCell = nil
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .overlay {
            if viewModel.showAddStudentsPopup {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showAddStudentsPopup = false
                        }
                    }

                AddStudentsPopup(
                    schoolClass: schoolClass,
                    onAddSingle: {
                        viewModel.showAddStudentsPopup = false
                        viewModel.addStudentNameDraft = ""
                        viewModel.showAddStudentSheet = true
                    },
                    onImportCommitted: {
                        viewModel.refreshRows()
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showAddStudentsPopup = false
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.settingsTarget?.id)
        .animation(.easeInOut(duration: 0.2), value: viewModel.activeInputCell?.id)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showAddStudentsPopup)
        .animation(.easeInOut(duration: 0.2), value: viewModel.movingNodeID)
        .animation(.easeInOut(duration: 0.2), value: viewModel.movingStudentID)
        .onChange(of: focusedStudentID) {
            if viewModel.editingStudentID != nil, focusedStudentID == nil {
                endStudentEditing(commit: true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let movingID = viewModel.movingNodeID {
                moveBanner(for: movingID)
            } else if let movingStudentID = viewModel.movingStudentID {
                studentMoveBanner(for: movingStudentID)
            }
        }
    }

    // MARK: - Move Banner

    @ViewBuilder
    private func moveBanner(for movingID: UUID) -> some View {
        let title = GradeTileTree.findNode(in: viewModel.root, id: movingID)?.title ?? ""
        moveControlPanel(
            icon: "rectangle.split.3x1",
            title: "\"\(title)\" wird verschoben",
            subtitle: "Waehle jetzt eine markierte Einfuegeposition im Tabellenkopf.",
            onCancel: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    viewModel.movingNodeID = nil
                }
            }
        )
    }

    @ViewBuilder
    private func studentMoveBanner(for movingStudentID: UUID) -> some View {
        let name = viewModel.rows.first(where: { $0.id == movingStudentID })?.studentName ?? ""
        moveControlPanel(
            icon: "text.line.first.and.arrowtriangle.forward",
            title: "\"\(name)\" wird verschoben",
            subtitle: "Waehle links eine markierte Einfuegeposition fuer die Reihenfolge.",
            onCancel: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    viewModel.movingStudentID = nil
                }
            }
        )
    }

    // MARK: - Name Column

    var nameColumnHeader: some View {
        ZStack(alignment: .topLeading) {
            Text("Schülername")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Table.textPrimary)
                .padding(.top, 10)
                .padding(.leading, 10)
        }
        .frame(width: nameColumnWidth, height: headerHeight)
        .background(Color.Table.headerBackground)
        .overlay {
            Rectangle()
                .strokeBorder(Color.Table.border.opacity(0.85), lineWidth: 0.8)
        }
    }

    private func studentNameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: {
                viewModel.rows.first(where: { $0.id == id })?.studentName ?? ""
            },
            set: { newValue in
                viewModel.updateRowStudentName(studentID: id, name: newValue)
            }
        )
    }

    private func beginStudentEditing(_ studentID: UUID) {
        endStudentEditing(commit: true)
        viewModel.editStudentOriginalName = viewModel.rows.first(where: { $0.id == studentID })?.studentName ?? ""
        viewModel.editingStudentID = studentID
        DispatchQueue.main.async {
            focusedStudentID = studentID
        }
    }

    private func endStudentEditing(commit: Bool) {
        guard let studentID = viewModel.editingStudentID else { return }
        if commit {
            let currentName = viewModel.rows.first(where: { $0.id == studentID })?.studentName ?? ""
            viewModel.renameStudent(studentID: studentID, fullName: currentName)
        } else {
            viewModel.updateRowStudentName(studentID: studentID, name: viewModel.editStudentOriginalName)
        }
        focusedStudentID = nil
        viewModel.editingStudentID = nil
        viewModel.editStudentOriginalName = ""
    }

    var nameColumnRows: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(viewModel.rows) { row in
                    studentRowView(for: row)
                }

                Button {
                    viewModel.showAddStudentsPopup = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: nameColumnWidth - 12, height: 32)
                        .background(Color.blue.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .frame(width: nameColumnWidth, height: cellHeight + 16)
                .background(Color.Table.cellBackground)
            }

            if let movingStudentID = viewModel.movingStudentID {
                studentInsertionSlotsOverlay(movingStudentID: movingStudentID)
            }
        }
    }

    @ViewBuilder
    private func studentRowView(for row: StudentGradeRow) -> some View {
        let isEditing = viewModel.editingStudentID == row.id
        let isMoving = viewModel.movingStudentID == row.id

        Group {
            if isEditing {
                TextField("", text: studentNameBinding(for: row.id), prompt: Text("Name"))
                    .textFieldStyle(.plain)
                    .focused($focusedStudentID, equals: row.id)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.Table.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .frame(width: nameColumnWidth - 12, height: cellHeight - 6, alignment: .leading)
                    .background(Color.Table.cellBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.blue, lineWidth: 1)
                    }
                    .onSubmit {
                        endStudentEditing(commit: true)
                    }
            } else {
                Text(row.studentName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.Table.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .frame(width: nameColumnWidth - 12, height: cellHeight - 6, alignment: .leading)
                    .background(Color.Table.cellBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isMoving ? Color.Theme.primaryBlue.opacity(0.9) : Color.Table.border,
                                lineWidth: isMoving ? 2 : 0.8
                            )
                    }
                    .background {
                        if isMoving {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.Theme.lightBlue.opacity(0.16),
                                            Color.Theme.primaryBlue.opacity(0.05)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.Theme.primaryBlue.opacity(0.12), radius: 10, y: 3)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        beginStudentEditing(row.id)
                    }
            }
        }
        .frame(width: nameColumnWidth, height: cellHeight)
        .contextMenu {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.movingNodeID = nil
                    viewModel.movingStudentID = viewModel.movingStudentID == row.id ? nil : row.id
                }
            } label: {
                Label("Verschieben", systemImage: "arrow.up.and.down")
            }

            Button(role: .destructive) {
                requestDeleteStudent(id: row.id)
            } label: {
                Label("Schüler löschen", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func studentInsertionSlotsOverlay(movingStudentID: UUID) -> some View {
        let slots = computeStudentInsertionSlots(movingStudentID: movingStudentID)
        ForEach(slots) { slot in
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.moveStudent(using: slot.action, studentID: movingStudentID)
                    viewModel.movingStudentID = nil
                }
            } label: {
                studentInsertionSlotLabel(for: slot.action)
                    .frame(width: nameColumnWidth, height: slot.slotHeight)
            }
            .buttonStyle(.plain)
            .offset(y: slot.y)
        }
    }

    private func studentInsertionSlotLabel(for action: StudentInsertionAction) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.001))

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.Table.textSecondary.opacity(0.34))
                .frame(width: nameColumnWidth - 26, height: 2)

            studentDirectionalMarker(for: action)
        }
        .padding(.horizontal, 6)
    }

    private func computeStudentInsertionSlots(movingStudentID: UUID) -> [StudentInsertionSlot] {
        let otherRows = viewModel.rows.filter { $0.id != movingStudentID }
        guard !otherRows.isEmpty else { return [] }

        var slots: [StudentInsertionSlot] = []
        for (index, row) in otherRows.enumerated() {
            let y = CGFloat(index) * cellHeight
            slots.append(
                StudentInsertionSlot(
                    id: "before-\(row.id.uuidString)",
                    y: y,
                    slotHeight: max(cellHeight * 0.5, 18),
                    action: .beforeStudent(row.id)
                )
            )

            if index == otherRows.count - 1 {
                slots.append(
                    StudentInsertionSlot(
                        id: "after-\(row.id.uuidString)",
                        y: y + cellHeight * 0.5,
                        slotHeight: max(cellHeight * 0.5, 18),
                        action: .afterStudent(row.id)
                    )
                )
            }
        }
        return slots
    }

    @ViewBuilder
    private func studentDirectionalMarker(for action: StudentInsertionAction) -> some View {
        switch action {
        case .beforeStudent:
            VStack(spacing: 0) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color.Table.textSecondary.opacity(0.65))
                Rectangle()
                    .fill(Color.Table.textSecondary.opacity(0.34))
                    .frame(width: 1.5, height: 8)
            }
            .offset(y: -5)
        case .afterStudent:
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.Table.textSecondary.opacity(0.34))
                    .frame(width: 1.5, height: 8)
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color.Table.textSecondary.opacity(0.65))
            }
            .offset(y: 5)
        }
    }

    private func moveControlPanel(
        icon: String,
        title: String,
        subtitle: String,
        onCancel: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.Theme.lightBlue.opacity(0.2), Color.Theme.primaryBlue.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.Theme.primaryBlue)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Table.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.Table.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.Table.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.72))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }


}

private struct SelectedNodeActionsDialogModifier: ViewModifier {
    @Binding var activeNodeID: UUID?
    @Binding var movingNodeID: UUID?
    let onDelete: (UUID) -> Void

    private var isPresented: Binding<Bool> {
        Binding(
            get: { activeNodeID != nil },
            set: { if !$0 { activeNodeID = nil } }
        )
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Bereichsaktionen",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            if let nodeID = activeNodeID {
                Button("Verschieben beenden") {
                    if movingNodeID == nodeID {
                        movingNodeID = nil
                    }
                    activeNodeID = nil
                }

                Button("Löschen", role: .destructive) {
                    onDelete(nodeID)
                    activeNodeID = nil
                }
            }

            Button("Abbrechen", role: .cancel) {
                activeNodeID = nil
            }
        } message: {
            Text("Aktionen für den ausgewählten Bereich.")
        }
    }
}
