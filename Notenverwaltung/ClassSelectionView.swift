//
//  ClassSelectionView.swift
//  Notenverwaltung
//
//  Klassenübersicht + gekoppelter Kachelkopf/Tabelle
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct GradeBookMainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var classes: [SchoolClass] = []
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            Color.systemGroupedBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    LazyVStack(spacing: 16) {
                        ForEach(classes) { schoolClass in
                            NavigationLink {
                                ClassGradebooksDetailView(
                                    schoolClass: schoolClass
                                )
                            } label: {
                                ClassCard(
                                    schoolClass: schoolClass,
                                    studentCount: schoolClass.students.count
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("TeacherApp")
        .adaptiveNavigationBarTitleDisplayMode(.large)
        .task {
            loadDataIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deine Klassen")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("\(classes.count) \(classes.count == 1 ? "Klasse" : "Klassen")")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func loadDataIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true

        let existingClasses = fetchClasses()
        if existingClasses.isEmpty {
            MockSeedDataService.seedIfNeeded(context: modelContext)
        }

        classes = fetchClasses()

        // Ensure each class has at least one tab entity
        for schoolClass in classes {
            GradebookRepository.ensureDefaultTab(for: schoolClass, in: modelContext)
        }
    }

    private func fetchClasses() -> [SchoolClass] {
        let descriptor = FetchDescriptor<SchoolClass>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
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

struct GradebookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let schoolClass: SchoolClass
    let tab: GradebookTabEntity
    @State private var viewModel: GradebookDetailViewModel

    @FocusState private var focusedStudentID: UUID?

    private let nameColumnWidth: CGFloat = 180
    private let defaultColumnWidth: CGFloat = 90
    private let minColumnWidth: CGFloat = 75
    private let maxColumnWidth: CGFloat = 300
    private let cellHeight: CGFloat = 38
    private let headerGap: CGFloat = 0

    init(schoolClass: SchoolClass, tab: GradebookTabEntity, context: ModelContext) {
        self.schoolClass = schoolClass
        self.tab = tab
        self._viewModel = State(initialValue: GradebookDetailViewModel(
            schoolClass: schoolClass, tab: tab, context: context
        ))
    }

    private var columns: [GradebookColumn] {
        viewModel.columns
    }

    private var visibleColumnIDs: Set<UUID> {
        Set(columns.map(\.nodeID))
    }

    private var headerDepth: Int {
        max(depth(of: viewModel.root), 1)
    }

    private var headerHeight: CGFloat {
        CGFloat(headerDepth) * cellHeight + CGFloat(max(headerDepth - 1, 0)) * headerGap
    }

    private var totalColumnsWidth: CGFloat {
        columns.reduce(CGFloat(0)) { $0 + width(for: $1.nodeID) }
    }

    private var gridContentHeight: CGFloat {
        headerHeight + CGFloat(viewModel.rows.count) * cellHeight
    }

    private var gridRowsHeight: CGFloat {
        CGFloat(viewModel.rows.count) * cellHeight
    }

    private var nameColumnContentHeight: CGFloat {
        gridContentHeight + cellHeight + 16
    }

    private var nameColumnRowsHeight: CGFloat {
        nameColumnContentHeight - headerHeight
    }

    // MARK: - Node Width Cache (Recursive Layout)

    private var nodeWidthCache: [UUID: CGFloat] {
        var cache: [UUID: CGFloat] = [:]
        _ = computeNodeWidth(node: viewModel.root, cache: &cache)
        return cache
    }

    @discardableResult
    private func computeNodeWidth(node: GradeTileNode, cache: inout [UUID: CGFloat]) -> CGFloat {
        if node.children.isEmpty {
            let w = width(for: node.id)
            cache[node.id] = w
            return w
        }
        let ownWidth: CGFloat = visibleColumnIDs.contains(node.id) ? width(for: node.id) : 0
        let childrenWidth = node.children.reduce(CGFloat(0)) { $0 + computeNodeWidth(node: $1, cache: &cache) }
        let total = ownWidth + childrenWidth
        cache[node.id] = total
        return total
    }

    // MARK: - Recursive Header Rendering

    private func headerNodeView(
        node: GradeTileNode,
        level: Int,
        isRoot: Bool,
        parentIsCalculation: Bool,
        availableHeight: CGFloat,
        widthCache: [UUID: CGFloat]
    ) -> AnyView {
        let nodeWidth = widthCache[node.id] ?? defaultColumnWidth
        let isLeaf = node.children.isEmpty
        let thisTileIsMoving = viewModel.movingNodeID == node.id
        let isInMoveMode = viewModel.movingNodeID != nil

        if isLeaf {
            return AnyView(
                HeaderTileView(
                    node: node,
                    isRoot: isRoot,
                    level: level,
                    parentIsCalculation: parentIsCalculation,
                    width: nodeWidth,
                    height: availableHeight,
                    isLeaf: true,
                    showWeightWarning: false,
                    isMoving: thisTileIsMoving,
                    onWeightChange: { viewModel.updateWeightAndRedistribute(nodeID: node.id, newWeight: $0) },
                    onAddInput: { viewModel.addChild(to: node.id, type: .input) },
                    onAddCalculation: { viewModel.addChild(to: node.id, type: .calculation) },
                    onAddSiblingArea: { viewModel.addSiblingArea(after: node.id) },
                    onOpenSettings: { viewModel.settingsTarget = TileSettingsTarget(id: node.id) },
                    onAutoDistribute: { viewModel.autoDistributeWeights(for: node.id) },
                    onDelete: { requestDeleteNode(for: node.id) },
                    onTitleSubmit: { viewModel.updateNodeTitle(nodeID: node.id, newTitle: $0) },
                    onStartMove: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.movingNodeID = viewModel.movingNodeID == node.id ? nil : node.id
                        }
                    }
                )
                .allowsHitTesting(isInMoveMode ? thisTileIsMoving : true)
                .zIndex(thisTileIsMoving ? 100 : 0)
            )
        } else {
            let remainingHeight = availableHeight - cellHeight

            return AnyView(
                VStack(spacing: 0) {
                    HeaderTileView(
                        node: node,
                        isRoot: isRoot,
                        level: level,
                        parentIsCalculation: parentIsCalculation,
                        width: nodeWidth,
                        height: cellHeight,
                        isLeaf: false,
                        showWeightWarning: node.type == .calculation && !GradeTileTree.isWeightValid(for: node),
                        isMoving: thisTileIsMoving,
                        onWeightChange: { viewModel.updateWeightAndRedistribute(nodeID: node.id, newWeight: $0) },
                        onAddInput: { viewModel.addChild(to: node.id, type: .input) },
                        onAddCalculation: { viewModel.addChild(to: node.id, type: .calculation) },
                        onAddSiblingArea: { viewModel.addSiblingArea(after: node.id) },
                        onOpenSettings: { viewModel.settingsTarget = TileSettingsTarget(id: node.id) },
                        onAutoDistribute: { viewModel.autoDistributeWeights(for: node.id) },
                        onDelete: { requestDeleteNode(for: node.id) },
                        onTitleSubmit: { viewModel.updateNodeTitle(nodeID: node.id, newTitle: $0) },
                        onStartMove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.movingNodeID = viewModel.movingNodeID == node.id ? nil : node.id
                            }
                        }
                    )
                    .allowsHitTesting(isInMoveMode ? thisTileIsMoving : true)
                    .zIndex(thisTileIsMoving ? 100 : 0)
                    .frame(width: nodeWidth, height: cellHeight)

                    if remainingHeight > 0 {
                        HStack(spacing: 0) {
                            if visibleColumnIDs.contains(node.id) {
                                let ownColWidth = width(for: node.id)
                                containerBackground(for: node, level: level)
                                    .frame(width: ownColWidth, height: remainingHeight)
                            }

                            ForEach(node.children, id: \.id) { child in
                                headerNodeView(
                                    node: child,
                                    level: level + 1,
                                    isRoot: false,
                                    parentIsCalculation: node.type == .calculation,
                                    availableHeight: remainingHeight,
                                    widthCache: widthCache
                                )
                            }
                        }
                        .frame(height: remainingHeight)
                    }
                }
                .frame(width: nodeWidth, height: availableHeight)
            )
        }
    }

    // MARK: - Insertion Slots

    @ViewBuilder
    private func insertionSlotsOverlay(movingID: UUID, headerTotalHeight: CGFloat, widthCache: [UUID: CGFloat]) -> some View {
        let slots = computeInsertionSlotsV2(movingID: movingID, widthCache: widthCache)
        ForEach(slots) { slot in
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.executeInsertionAction(slot.action, draggedID: movingID)
                    viewModel.movingNodeID = nil
                }
            } label: {
                ZStack {
                    Color.clear
                        .frame(width: slot.slotWidth, height: slot.slotHeight)
                        .contentShape(Rectangle())
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 3, height: slot.slotHeight)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .offset(y: -slot.slotHeight / 2 + 5)
                }
            }
            .buttonStyle(.plain)
            .zIndex(50)
            .offset(x: slot.x, y: slot.y)
        }
    }

    private func computeInsertionSlotsV2(movingID: UUID, widthCache: [UUID: CGFloat]) -> [InsertionSlot] {
        var slots: [InsertionSlot] = []
        collectInsertionSlotsV2(
            node: viewModel.root,
            level: 0,
            xOffset: 0,
            movingID: movingID,
            widthCache: widthCache,
            slots: &slots
        )
        return slots
    }

    private func collectInsertionSlotsV2(
        node: GradeTileNode,
        level: Int,
        xOffset: CGFloat,
        movingID: UUID,
        widthCache: [UUID: CGFloat],
        slots: inout [InsertionSlot]
    ) {
        guard node.type == .calculation else { return }
        if node.id == movingID { return }
        if GradeTileTree.isDescendant(root: viewModel.root, ancestorID: movingID, possibleDescendantID: node.id) {
            return
        }

        let children = node.children
        let childLevel = level + 1
        let slotY = CGFloat(childLevel) * cellHeight
        let slotH = CGFloat(headerDepth - childLevel) * cellHeight
        let lineWidth: CGFloat = 28

        var childXStart = xOffset
        if visibleColumnIDs.contains(node.id) {
            childXStart += width(for: node.id)
        }

        let relevantChildren = children.filter { $0.id != movingID }

        if relevantChildren.isEmpty {
            let parentW = widthCache[node.id] ?? defaultColumnWidth
            let cx = xOffset + parentW / 2 - lineWidth / 2
            slots.append(InsertionSlot(
                id: "append-\(node.id.uuidString)",
                x: cx, y: slotY,
                slotWidth: lineWidth, slotHeight: max(slotH, cellHeight),
                action: .appendToParent(node.id),
                isVertical: true
            ))
        } else {
            var positions: [(child: GradeTileNode, xStart: CGFloat)] = []
            var currentX = childXStart
            for child in children {
                if child.id == movingID {
                    currentX += widthCache[child.id] ?? defaultColumnWidth
                    continue
                }
                positions.append((child, currentX))
                currentX += widthCache[child.id] ?? defaultColumnWidth
            }

            if let first = positions.first {
                slots.append(InsertionSlot(
                    id: "before-\(first.child.id.uuidString)",
                    x: first.xStart - lineWidth / 2, y: slotY,
                    slotWidth: lineWidth, slotHeight: max(slotH, cellHeight),
                    action: .beforeSibling(first.child.id),
                    isVertical: true
                ))
            }

            for pos in positions {
                let childW = widthCache[pos.child.id] ?? defaultColumnWidth
                let afterX = pos.xStart + childW - lineWidth / 2
                slots.append(InsertionSlot(
                    id: "after-\(pos.child.id.uuidString)",
                    x: afterX, y: slotY,
                    slotWidth: lineWidth, slotHeight: max(slotH, cellHeight),
                    action: .afterSibling(pos.child.id),
                    isVertical: true
                ))
            }
        }

        var recurseX = childXStart
        for child in children {
            if child.id != movingID {
                collectInsertionSlotsV2(
                    node: child,
                    level: childLevel,
                    xOffset: recurseX,
                    movingID: movingID,
                    widthCache: widthCache,
                    slots: &slots
                )
            }
            recurseX += widthCache[child.id] ?? defaultColumnWidth
        }
    }

    // MARK: - Table Layout

    private func scaledTableSection<Content: View>(
        baseWidth: CGFloat,
        baseHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: baseWidth, height: baseHeight, alignment: .topLeading)
            .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
            .frame(
                width: baseWidth * viewModel.zoomScale,
                height: baseHeight * viewModel.zoomScale,
                alignment: .topLeading
            )
    }

    private var stickyGridHeaderViewport: some View {
        GeometryReader { geometry in
            scaledTableSection(
                baseWidth: totalColumnsWidth,
                baseHeight: headerHeight
            ) {
                gridHeaderView
            }
            .offset(x: viewModel.horizontalScrollOffset)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        .frame(height: headerHeight * viewModel.zoomScale)
    }

    private var stickyTableHeaderRow: some View {
        HStack(alignment: .top, spacing: 0) {
            scaledTableSection(
                baseWidth: nameColumnWidth,
                baseHeight: headerHeight
            ) {
                nameColumnHeader
            }

            stickyGridHeaderViewport
        }
    }

    @ViewBuilder
    private var horizontalGridRowsScrollView: some View {
        #if os(iOS)
        SyncedHorizontalScrollView(
            showsHorizontalScrollIndicator: false,
            onOffsetChange: { viewModel.horizontalScrollOffset = $0 }
        ) {
            scaledTableSection(
                baseWidth: totalColumnsWidth,
                baseHeight: gridRowsHeight
            ) {
                gridRowsView
            }
        }
        .frame(height: gridRowsHeight * viewModel.zoomScale, alignment: .topLeading)
        #else
        ScrollView(.horizontal) {
            scaledTableSection(
                baseWidth: totalColumnsWidth,
                baseHeight: gridRowsHeight
            ) {
                gridRowsView
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: GridHorizontalContentOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("gradebookHorizontalScroll")).minX
                    )
                }
            }
        }
        .coordinateSpace(name: "gradebookHorizontalScroll")
        .frame(height: gridRowsHeight * viewModel.zoomScale, alignment: .topLeading)
        #endif
    }

    private var scrollableTableBody: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                scaledTableSection(
                    baseWidth: nameColumnWidth,
                    baseHeight: nameColumnRowsHeight
                ) {
                    nameColumnRows
                }

                horizontalGridRowsScrollView
            }
            .contentShape(Rectangle())
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    private var modernZoomableTableLayout: some View {
        VStack(spacing: 0) {
            stickyTableHeaderRow
            scrollableTableBody
        }
        #if !os(iOS)
        .onPreferenceChange(GridHorizontalContentOffsetPreferenceKey.self) { value in
            viewModel.horizontalScrollOffset = value
        }
        #endif
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    viewModel.zoomScale = max(0.5, min(viewModel.baseZoomScale * value.magnification, 3.0))
                }
                .onEnded { _ in
                    viewModel.baseZoomScale = viewModel.zoomScale
                }
        )
    }

    private var legacyZoomableTableLayout: some View {
        VStack(spacing: 0) {
            stickyTableHeaderRow
            scrollableTableBody
        }
        #if !os(iOS)
        .onPreferenceChange(GridHorizontalContentOffsetPreferenceKey.self) { value in
            viewModel.horizontalScrollOffset = value
        }
        #endif
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    viewModel.zoomScale = max(0.5, min(viewModel.baseZoomScale * value, 3.0))
                }
                .onEnded { _ in
                    viewModel.baseZoomScale = viewModel.zoomScale
                }
        )
    }

    private var zoomableTableLayout: AnyView {
        if #available(iOS 17.0, macOS 14.0, *) {
            return AnyView(modernZoomableTableLayout)
        } else {
            return AnyView(legacyZoomableTableLayout)
        }
    }

    // MARK: - Body

    var body: some View {
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

    private var nameColumnHeader: some View {
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

    private var nameColumnRows: some View {
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

    // MARK: - Leaf Columns

    private var leafColumns: [LeafColumnInfo] {
        var result: [LeafColumnInfo] = []
        collectLeaves(node: viewModel.root, result: &result)
        return result
    }

    private func collectLeaves(node: GradeTileNode, result: inout [LeafColumnInfo]) {
        if visibleColumnIDs.contains(node.id) {
            result.append(LeafColumnInfo(nodeID: node.id, width: width(for: node.id)))
        }
        for child in node.children {
            collectLeaves(node: child, result: &result)
        }
    }

    // MARK: - Container Background

    private func containerBackground(for node: GradeTileNode, level: Int) -> Color {
        let normalizedLevel = min(max(level, 0), 4)
        switch node.colorStyle {
        case .automatic:
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

    private func tileCornerRadius(for level: Int) -> CGFloat {
        switch min(max(level, 0), 4) {
        case 0: return 12
        case 1: return 10
        case 2: return 8
        default: return 6
        }
    }

    // MARK: - Grid Header & Rows

    private var gridHeaderView: some View {
        let leaves = leafColumns
        let totalWidth = leaves.reduce(CGFloat(0)) { $0 + $1.width }
        let headerTotalH = CGFloat(headerDepth) * cellHeight
        let cache = nodeWidthCache

        return ZStack(alignment: .topLeading) {
            headerNodeView(
                node: viewModel.root,
                level: 0,
                isRoot: true,
                parentIsCalculation: false,
                availableHeight: headerTotalH,
                widthCache: cache
            )

            if let movingID = viewModel.movingNodeID {
                insertionSlotsOverlay(
                    movingID: movingID,
                    headerTotalHeight: headerTotalH,
                    widthCache: cache
                )
            }
        }
        .frame(width: totalWidth, height: headerTotalH)
    }

    private var gridRowsView: some View {
        let leaves = leafColumns
        let totalWidth = leaves.reduce(CGFloat(0)) { $0 + $1.width }

        return VStack(spacing: 0) {
            ForEach(viewModel.rows) { row in
                HStack(spacing: 0) {
                    ForEach(leaves, id: \.nodeID) { leaf in
                        let column = columns.first(where: { $0.nodeID == leaf.nodeID })
                        if column?.type == .input {
                            inputCell(rowID: row.id, nodeID: leaf.nodeID)
                        } else {
                            calculatedCell(row: row, nodeID: leaf.nodeID)
                        }
                    }
                }
                .frame(height: cellHeight)
            }
        }
        .frame(width: totalWidth)
    }

    // MARK: - Cells

    private func inputCell(rowID: UUID, nodeID: UUID) -> some View {
        let displayValue = viewModel.inputValue(rowID: rowID, nodeID: nodeID)

        return ZStack {
            if let option = EmojiOption.fromStoredValue(displayValue) {
                Image(systemName: option.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(option.primaryColor, option.primaryColor.opacity(0.3))
            } else {
                Text(displayValue.isEmpty ? " " : displayValue)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(Color.Table.textPrimary)
            }
        }
        .frame(width: width(for: nodeID), height: cellHeight)
        .background(columnBackground(for: nodeID, isCalculated: false))
        .overlay(cellBorder)
        .overlay(alignment: .trailing) {
            columnDivider(for: nodeID, isCalculated: false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.inputPopupDraft = displayValue
            viewModel.inputPopupCategory = .numbers
            viewModel.activeInputCell = GradeInputCellTarget(rowID: rowID, nodeID: nodeID)
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.pendingClearCell = GradeInputCellTarget(rowID: rowID, nodeID: nodeID)
                viewModel.showClearCellDialog = true
            } label: {
                Label("Zelle leeren", systemImage: "trash")
            }
        }
    }

    private func calculatedCell(row: StudentGradeRow, nodeID: UUID) -> some View {
        let value = GradeTileTree.findNode(in: viewModel.root, id: nodeID).flatMap {
            GradeTileTree.calculateValue(for: $0, row: row, roundingDecimals: viewModel.roundingDecimals)
        }

        let text = value.map { String(format: "%0.2f", $0) } ?? "—"

        return Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.Table.textSecondary)
            .frame(width: width(for: nodeID), height: cellHeight)
            .background(columnBackground(for: nodeID, isCalculated: true))
            .overlay(cellBorder)
            .overlay(alignment: .trailing) {
                columnDivider(for: nodeID, isCalculated: true)
            }
    }

    private var cellBorder: some View {
        Rectangle().strokeBorder(Color.Table.border.opacity(0.9), lineWidth: 0.9)
    }

    @ViewBuilder
    private func columnDivider(for nodeID: UUID, isCalculated: Bool) -> some View {
        let depth = nodeDepth(for: nodeID)
        let baseOpacity: Double = isCalculated ? 0.42 : 0.26
        let depthBoost = max(0.0, 0.12 - Double(min(depth, 3)) * 0.03)
        let lineWidth: CGFloat = isCalculated ? 1.4 : 1.0

        Rectangle()
            .fill(Color.Table.textSecondary.opacity(baseOpacity + depthBoost))
            .frame(width: lineWidth)
    }

    // MARK: - Helpers

    private func depth(of node: GradeTileNode) -> Int {
        if node.children.isEmpty { return 1 }
        return 1 + (node.children.map(depth(of:)).max() ?? 0)
    }
    
    private func columnBackground(for nodeID: UUID, isCalculated: Bool) -> Color {
        let style = effectiveColorStyle(for: nodeID)
        let depth = nodeDepth(for: nodeID)
        let normalizedDepth = min(max(depth, 0), 4)
        let base: Color
        switch style {
        case .automatic:
            if isCalculated {
                switch normalizedDepth {
                case 0:
                    base = Color.Table.hover
                case 1:
                    base = Color.Table.hover.opacity(0.92)
                default:
                    base = Color.Table.hover.opacity(0.84)
                }
            } else {
                switch normalizedDepth {
                case 0:
                    base = Color.Table.cellBackground
                case 1:
                    base = Color.Table.cellBackground.opacity(0.97)
                default:
                    base = Color.Table.cellBackground.opacity(0.94)
                }
            }
        case .slate:
            base = Color(red: 0.92, green: 0.93, blue: 0.95)
        case .blue:
            base = Color(red: 0.88, green: 0.93, blue: 0.99)
        case .green:
            base = Color(red: 0.89, green: 0.96, blue: 0.91)
        case .orange:
            base = Color(red: 0.99, green: 0.93, blue: 0.86)
        case .red:
            base = Color(red: 0.99, green: 0.90, blue: 0.90)
        }
        return isCalculated ? base.opacity(0.85) : base
    }

    private func nodeDepth(for nodeID: UUID) -> Int {
        nodeDepth(in: viewModel.root, targetID: nodeID, currentDepth: 0) ?? 0
    }

    private func nodeDepth(in node: GradeTileNode, targetID: UUID, currentDepth: Int) -> Int? {
        if node.id == targetID {
            return currentDepth
        }

        for child in node.children {
            if let foundDepth = nodeDepth(in: child, targetID: targetID, currentDepth: currentDepth + 1) {
                return foundDepth
            }
        }

        return nil
    }
    
    private func effectiveColorStyle(for nodeID: UUID) -> GradeTileColorStyle {
        resolveColorStyle(
            in: viewModel.root,
            targetID: nodeID,
            inherited: .automatic
        ) ?? .automatic
    }
    
    private func resolveColorStyle(
        in node: GradeTileNode,
        targetID: UUID,
        inherited: GradeTileColorStyle
    ) -> GradeTileColorStyle? {
        let nextInherited = node.colorStyle == .automatic ? inherited : node.colorStyle
        if node.id == targetID {
            return nextInherited
        }
        for child in node.children {
            if let resolved = resolveColorStyle(in: child, targetID: targetID, inherited: nextInherited) {
                return resolved
            }
        }
        return nil
    }

    private func width(for nodeID: UUID) -> CGFloat {
        viewModel.columnWidths[nodeID] ?? preferredWidth(for: nodeID)
    }

    private func preferredWidth(for nodeID: UUID) -> CGFloat {
        guard let node = GradeTileTree.findNode(in: viewModel.root, id: nodeID) else {
            return defaultColumnWidth
        }

        let title = node.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return defaultColumnWidth
        }

        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let measuredTextWidth = (title as NSString).size(withAttributes: [.font: font]).width
        #elseif canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let measuredTextWidth = (title as NSString).size(withAttributes: [.font: font]).width
        #else
        let measuredTextWidth = CGFloat(title.count) * 8
        #endif

        let parentIsCalculation = nodeHasCalculationParent(nodeID)
        let settingsControlWidth: CGFloat = 26
        let weightControlWidth: CGFloat = parentIsCalculation ? 50 : 0
        let calcControlWidth: CGFloat = node.type == .calculation ? 40 : 0
        let horizontalInsets: CGFloat = 16
        let interItemSpacing: CGFloat = 12

        let requiredWidth = measuredTextWidth
            + settingsControlWidth
            + weightControlWidth
            + calcControlWidth
            + horizontalInsets
            + interItemSpacing

        return min(max(requiredWidth, minColumnWidth), maxColumnWidth)
    }

    private func nodeHasCalculationParent(_ nodeID: UUID) -> Bool {
        hasCalculationParent(in: viewModel.root, targetID: nodeID, parentIsCalculation: false) ?? false
    }

    private func hasCalculationParent(
        in node: GradeTileNode,
        targetID: UUID,
        parentIsCalculation: Bool
    ) -> Bool? {
        if node.id == targetID {
            return parentIsCalculation
        }

        for child in node.children {
            if let result = hasCalculationParent(
                in: child,
                targetID: targetID,
                parentIsCalculation: node.type == .calculation
            ) {
                return result
            }
        }

        return nil
    }

    private func requestDeleteNode(for id: UUID) {
        guard viewModel.root.id != id else { return }
        viewModel.pendingDeleteNodeID = id
        viewModel.showDeleteNodeDialog = true
    }

    private func requestDeleteStudent(id: UUID) {
        viewModel.pendingDeleteStudentID = id
        viewModel.showDeleteStudentDialog = true
    }
}


// Types extracted to GradebookViewHelpers.swift, component views extracted to Features/GradeManagement/Views/

#Preview("Klassen") {
    NavigationStack {
        GradeBookMainView()
    }
    .modelContainer(for: [SchoolClass.self, GradebookTabEntity.self, GradebookNodeEntity.self, GradebookRowEntity.self, GradebookCellValueEntity.self, Student.self, GradeEntry.self, Assessment.self, GradeComment.self, GradebookSnapshot.self], inMemory: true)
}
