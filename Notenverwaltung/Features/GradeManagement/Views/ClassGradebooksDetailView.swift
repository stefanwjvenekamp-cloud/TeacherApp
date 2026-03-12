import SwiftUI
import SwiftData

struct ClassGradebooksDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let schoolClass: SchoolClass

    private let tabHeight: CGFloat = 38
    private let tabsHeaderHeight: CGFloat = 46
    @FocusState private var focusedTabID: UUID?
    @State private var selectedTabID: UUID?
    @State private var editingTabID: UUID?
    @State private var editOriginalTitle: String = ""
    @State private var pendingDeleteTabID: UUID?
    @State private var showDeleteDialog = false
    @State private var suppressNextOutsideBlur = false

    var body: some View {
        VStack(spacing: 8) {
            tabsHeader
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 2)

            if let selectedTab = selectedTabEntity {
                GradebookDetailView(
                    schoolClass: schoolClass,
                    tab: selectedTab,
                    context: modelContext
                )
                .id(selectedTab.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        endTabEditing(commit: true)
                    }
                )
            } else {
                ContentUnavailableView(
                    "Keine Notentabelle",
                    systemImage: "tablecells",
                    description: Text("Füge eine neue Tabelle über das Plus hinzu.")
                )
                .onTapGesture {
                    endTabEditing(commit: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .navigationTitle("\(schoolClass.name) – \(schoolClass.subject)")
        .adaptiveNavigationBarTitleDisplayMode(.inline)
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: focusedTabID) {
            if editingTabID != nil, focusedTabID == nil {
                endTabEditing(commit: true)
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                guard editingTabID != nil else { return }
                if suppressNextOutsideBlur {
                    suppressNextOutsideBlur = false
                    return
                }
                focusedTabID = nil
            },
            including: .subviews
        )
        .confirmationDialog("Reiter löschen?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                guard let tabID = pendingDeleteTabID else { return }
                deleteTab(id: tabID)
                pendingDeleteTabID = nil
            }
            Button("Abbrechen", role: .cancel) {
                pendingDeleteTabID = nil
            }
        } message: {
            Text("Dieser Reiter wird dauerhaft gelöscht.")
        }
    }

    private var tabsHeader: some View {
        ZStack(alignment: .leading) {
            Color.clear

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(persistedTabs) { tab in
                        tabView(for: tab)
                    }

                    Button {
                        endTabEditing(commit: true)
                        addNewTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.blue)
                            .frame(width: tabHeight, height: tabHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.secondarySystemGroupedBackground)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .frame(height: tabsHeaderHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var selectedTabEntity: GradebookTabEntity? {
        let selectedID = activeTabID
        return persistedTabs.first(where: { $0.id == selectedID })
    }

    private var persistedTabs: [GradebookTabEntity] {
        GradebookRepository.tabs(for: schoolClass)
    }

    private func tabTitleBinding(for tab: GradebookTabEntity) -> Binding<String> {
        Binding(
            get: {
                tab.title
            },
            set: { newValue in
                let oldValue = tab.title
                GradebookRepository.renameTab(tab, title: newValue, in: modelContext)
                if oldValue != newValue {
                    renameSemesterId(from: oldValue, to: newValue)
                }
            }
        )
    }

    private func renameSemesterId(from oldValue: String, to newValue: String) {
        guard !oldValue.isEmpty, !newValue.isEmpty else { return }
        let studentIDs = Set(schoolClass.students.map(\.id))
        let descriptor = FetchDescriptor<GradeEntry>()
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        for entry in entries where studentIDs.contains(entry.studentId) && entry.semesterId == oldValue {
            entry.semesterId = newValue
        }
    }

    @ViewBuilder
    private func tabView(for tab: GradebookTabEntity) -> some View {
        let isEditing = editingTabID == tab.id
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Neuer Reiter" : tab.title

        if isEditing {
            TextField("", text: tabTitleBinding(for: tab), prompt: Text("Neuer Reiter"))
                .textFieldStyle(.plain)
                .focused($focusedTabID, equals: tab.id)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        suppressNextOutsideBlur = true
                    }
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(height: tabHeight)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected(tab) ? Color.blue.opacity(0.15) : Color.secondarySystemGroupedBackground)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected(tab) ? Color.blue : Color.gray.opacity(0.18), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button(role: .destructive) {
                        requestDelete(for: tab.id)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                        requestDelete(for: tab.id)
                    }
                )
                .fixedSize(horizontal: true, vertical: false)
        } else {
            Button {
                endTabEditing(commit: true)
                selectedTabID = tab.id
            } label: {
                Text(title)
                    .lineLimit(1)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(height: tabHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected(tab) ? Color.blue.opacity(0.15) : Color.secondarySystemGroupedBackground)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected(tab) ? Color.blue : Color.gray.opacity(0.18), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    beginEditing(tab.id)
                }
            )
            .contextMenu {
                Button(role: .destructive) {
                    requestDelete(for: tab.id)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    requestDelete(for: tab.id)
                }
            )
            .fixedSize(horizontal: true, vertical: false)
        }
#if os(macOS)
        .onExitCommand {
            endTabEditing(commit: false)
        }
#endif
    }

    private var activeTabID: UUID? {
        if let selected = selectedTabID,
           persistedTabs.contains(where: { $0.id == selected }) {
            return selected
        }
        return persistedTabs.first?.id
    }

    private func isSelected(_ tab: GradebookTabEntity) -> Bool {
        tab.id == activeTabID
    }

    private func ensureValidSelection() {
        guard let firstID = persistedTabs.first?.id else {
            selectedTabID = nil
            return
        }
        if selectedTabID == nil || !persistedTabs.contains(where: { $0.id == selectedTabID }) {
            selectedTabID = firstID
        }
    }

    private func addNewTab() {
        let newTab = GradebookRepository.createTab(title: "", for: schoolClass, in: modelContext)
        selectedTabID = newTab.id
        beginEditing(newTab.id)
    }

    private func beginEditing(_ tabID: UUID) {
        endTabEditing(commit: true)
        selectedTabID = tabID
        editOriginalTitle = persistedTabs.first(where: { $0.id == tabID })?.title ?? ""
        editingTabID = tabID
        DispatchQueue.main.async {
            focusedTabID = tabID
        }
    }

    private func endTabEditing(commit: Bool) {
        guard let tabID = editingTabID else { return }
        if !commit,
           let tab = persistedTabs.first(where: { $0.id == tabID }) {
            let currentTitle = tab.title
            GradebookRepository.renameTab(tab, title: editOriginalTitle, in: modelContext)
            if currentTitle != editOriginalTitle {
                renameSemesterId(from: currentTitle, to: editOriginalTitle)
            }
        }
        focusedTabID = nil
        editingTabID = nil
        editOriginalTitle = ""
    }

    private func deleteTab(id: UUID) {
        if editingTabID == id {
            endTabEditing(commit: true)
        }
        if let tab = persistedTabs.first(where: { $0.id == id }) {
            GradebookRepository.deleteTab(tab, in: modelContext)
        }
        if focusedTabID == id {
            focusedTabID = nil
        }
        ensureValidSelection()
    }

    private func requestDelete(for id: UUID) {
        pendingDeleteTabID = id
        showDeleteDialog = true
    }
}

