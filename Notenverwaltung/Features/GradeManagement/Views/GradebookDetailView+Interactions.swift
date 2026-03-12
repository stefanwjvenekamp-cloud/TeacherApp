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
                    onAddSingle: {
                        viewModel.showAddStudentsPopup = false
                        viewModel.addStudentNameDraft = ""
                        viewModel.showAddStudentSheet = true
                    },
                    onImportStudents: { names in
                        viewModel.addStudents(names: names)
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
        .onChange(of: focusedStudentID) {
            if viewModel.editingStudentID != nil, focusedStudentID == nil {
                endStudentEditing(commit: true)
            }
        }
        .overlay(alignment: .top) {
            if let movingID = viewModel.movingNodeID {
                moveBanner(for: movingID)
            }
        }
    }

    // MARK: - Move Banner

    @ViewBuilder
    private func moveBanner(for movingID: UUID) -> some View {
        let title = GradeTileTree.findNode(in: viewModel.root, id: movingID)?.title ?? ""
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
            Text("\"\(title)\" verschieben")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.movingNodeID = nil
                }
            } label: {
                Text("Abbrechen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
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
        VStack(spacing: 0) {
            ForEach(viewModel.rows) { row in
                if viewModel.editingStudentID == row.id {
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
                        .frame(width: nameColumnWidth, height: cellHeight)
                        .onSubmit {
                            endStudentEditing(commit: true)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                requestDeleteStudent(id: row.id)
                            } label: {
                                Label("Schüler löschen", systemImage: "trash")
                            }
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
                                .strokeBorder(Color.Table.border, lineWidth: 0.8)
                        }
                        .frame(width: nameColumnWidth, height: cellHeight)
                        .contextMenu {
                            Button(role: .destructive) {
                                requestDeleteStudent(id: row.id)
                            } label: {
                                Label("Schüler löschen", systemImage: "trash")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            beginStudentEditing(row.id)
                        }
                }
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
    }


}
