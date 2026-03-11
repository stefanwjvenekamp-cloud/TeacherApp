//
//  ClassSelectionView.swift
//  Notenverwaltung
//
//  Klassenübersicht + gekoppelter Kachelkopf/Tabelle
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct GradeBookMainView: View {
    @State private var classes: [SchoolClass]
    @State private var gradebooksByClassID: [UUID: ClassGradebooksState]

    init() {
        if let saved = GradebookPersistence.load() {
            _classes = State(initialValue: saved.classes)
            _gradebooksByClassID = State(initialValue: saved.gradebooks)
        } else {
            let seed = MockClassData.seed()
            _classes = State(initialValue: seed.classes)
            _gradebooksByClassID = State(initialValue: seed.gradebooksByClassID)
        }
    }

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
                                    schoolClass: schoolClass,
                                    gradebooksState: binding(for: schoolClass)
                                )
                            } label: {
                                ClassCard(
                                    schoolClass: schoolClass,
                                    studentCount: selectedStudentCount(for: schoolClass)
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
        .navigationTitle("Notenverwaltung")
        .adaptiveNavigationBarTitleDisplayMode(.large)
        .onChange(of: gradebooksByClassID) {
            persistData()
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

    private func binding(for schoolClass: SchoolClass) -> Binding<ClassGradebooksState> {
        Binding(
            get: {
                gradebooksByClassID[schoolClass.id] ?? defaultGradebooksState(for: schoolClass)
            },
            set: { newValue in
                gradebooksByClassID[schoolClass.id] = newValue
            }
        )
    }

    private func defaultGradebooksState(for schoolClass: SchoolClass) -> ClassGradebooksState {
        let firstTab = GradebookTabState(
            schoolYear: schoolClass.schoolYear,
            gradebook: ClassGradebookState(root: GradeTileTree.standardRoot(), rows: [])
        )
        return ClassGradebooksState(tabs: [firstTab], selectedTabID: firstTab.id)
    }

    private func selectedStudentCount(for schoolClass: SchoolClass) -> Int {
        guard let state = gradebooksByClassID[schoolClass.id], !state.tabs.isEmpty else { return 0 }
        let selectedID = state.selectedTabID ?? state.tabs.first?.id
        let selectedTab = state.tabs.first(where: { $0.id == selectedID }) ?? state.tabs.first
        return selectedTab?.gradebook.rows.count ?? 0
    }

    private func persistData() {
        GradebookPersistence.save(classes: classes, gradebooks: gradebooksByClassID)
    }
}

struct ClassCard: View {
    let schoolClass: SchoolClass
    let studentCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(schoolClass.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(schoolClass.subject)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue.gradient)
            }
            .padding(24)
            .background(Color.secondarySystemGroupedBackground)

            Divider()

            HStack(spacing: 24) {
                StatItem(icon: "person.2.fill", value: "\(studentCount)", label: "Schüler")

                Divider()
                    .frame(height: 30)

                StatItem(icon: "calendar", value: schoolClass.schoolYear, label: "Schuljahr")

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.secondarySystemGroupedBackground.opacity(0.5))
        }
        .background(Color.secondarySystemGroupedBackground)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .contentShape(Rectangle())
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ClassGradebooksDetailView: View {
    let schoolClass: SchoolClass
    @Binding var gradebooksState: ClassGradebooksState

    private let tabHeight: CGFloat = 38
    private let tabsHeaderHeight: CGFloat = 46
    @FocusState private var focusedTabID: UUID?
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

            if let selectedBinding = selectedGradebookBinding {
                GradebookDetailView(
                    schoolClass: schoolClass,
                    gradebook: selectedBinding
                )
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
        .onChange(of: gradebooksState.tabs) {
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
                    ForEach(gradebooksState.tabs) { tab in
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

    private var selectedGradebookBinding: Binding<ClassGradebookState>? {
        let selectedID = activeTabID
        guard let index = gradebooksState.tabs.firstIndex(where: { $0.id == selectedID }) else { return nil }
        return Binding(
            get: { gradebooksState.tabs[index].gradebook },
            set: { gradebooksState.tabs[index].gradebook = $0 }
        )
    }

    private func tabTitleBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: {
                gradebooksState.tabs.first(where: { $0.id == id })?.schoolYear ?? ""
            },
            set: { newValue in
                guard let index = gradebooksState.tabs.firstIndex(where: { $0.id == id }) else { return }
                gradebooksState.tabs[index].schoolYear = newValue
            }
        )
    }

    @ViewBuilder
    private func tabView(for tab: GradebookTabState) -> some View {
        let isEditing = editingTabID == tab.id
        let title = tab.schoolYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Neuer Reiter" : tab.schoolYear

        if isEditing {
            TextField("", text: tabTitleBinding(for: tab.id), prompt: Text("Neuer Reiter"))
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
                gradebooksState.selectedTabID = tab.id
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
        if let selected = gradebooksState.selectedTabID,
           gradebooksState.tabs.contains(where: { $0.id == selected }) {
            return selected
        }
        return gradebooksState.tabs.first?.id
    }

    private func isSelected(_ tab: GradebookTabState) -> Bool {
        tab.id == activeTabID
    }

    private func ensureValidSelection() {
        guard let firstID = gradebooksState.tabs.first?.id else {
            gradebooksState.selectedTabID = nil
            return
        }
        if gradebooksState.selectedTabID == nil || !gradebooksState.tabs.contains(where: { $0.id == gradebooksState.selectedTabID }) {
            gradebooksState.selectedTabID = firstID
        }
    }

    private func addNewTab() {
        let tab = GradebookTabState(
            schoolYear: "",
            gradebook: ClassGradebookState(root: GradeTileTree.emptyRoot(), rows: [])
        )
        gradebooksState.tabs.append(tab)
        gradebooksState.selectedTabID = tab.id
        beginEditing(tab.id)
    }

    private func beginEditing(_ tabID: UUID) {
        endTabEditing(commit: true)
        gradebooksState.selectedTabID = tabID
        editOriginalTitle = gradebooksState.tabs.first(where: { $0.id == tabID })?.schoolYear ?? ""
        editingTabID = tabID
        DispatchQueue.main.async {
            focusedTabID = tabID
        }
    }

    private func endTabEditing(commit: Bool) {
        guard let tabID = editingTabID else { return }
        if !commit, let index = gradebooksState.tabs.firstIndex(where: { $0.id == tabID }) {
            gradebooksState.tabs[index].schoolYear = editOriginalTitle
        }
        focusedTabID = nil
        editingTabID = nil
        editOriginalTitle = ""
    }

    private func deleteTab(id: UUID) {
        if editingTabID == id {
            endTabEditing(commit: true)
        }
        gradebooksState.tabs.removeAll { $0.id == id }
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
    let schoolClass: SchoolClass
    @Binding var gradebook: ClassGradebookState

    @State private var showNewDialog = false
    @State private var showAddStudentSheet = false
    @State private var showAddStudentsPopup = false
    @State private var addStudentNameDraft = ""
    @State private var settingsTarget: TileSettingsTarget?
    @State private var activeInputCell: GradeInputCellTarget?
    @State private var inputPopupDraft = ""
    @State private var inputPopupCategory: GradeInputCategory = .numbers
    @State private var columnWidths: [UUID: CGFloat] = [:]
    @State private var zoomScale: CGFloat = 1.0
    @State private var baseZoomScale: CGFloat = 1.0
    /// The node currently being moved (tap-to-move mode).
    /// When set, other tiles show drop targets and the moving tile is visually lifted.
    @State private var movingNodeID: UUID?

    // Student name inline editing (double-tap)
    @State private var editingStudentID: UUID?
    @State private var editStudentOriginalName: String = ""
    @FocusState private var focusedStudentID: UUID?

    private let nameColumnWidth: CGFloat = 180
    private let defaultColumnWidth: CGFloat = 90
    private let minColumnWidth: CGFloat = 75
    private let maxColumnWidth: CGFloat = 300
    private let cellHeight: CGFloat = 38
    private let headerGap: CGFloat = 0

    private var columns: [GradebookColumn] {
        GradeTileTree.columns(from: gradebook.root)
    }

    private var visibleColumnIDs: Set<UUID> {
        Set(columns.map(\.nodeID))
    }

    private var headerDepth: Int {
        max(depth(of: gradebook.root), 1)
    }

    private var headerHeight: CGFloat {
        CGFloat(headerDepth) * cellHeight + CGFloat(max(headerDepth - 1, 0)) * headerGap
    }

    private var totalColumnsWidth: CGFloat {
        columns.reduce(CGFloat(0)) { $0 + width(for: $1.nodeID) }
    }

    private var gridContentHeight: CGFloat {
        headerHeight + CGFloat(gradebook.rows.count) * cellHeight
    }

    private var nameColumnContentHeight: CGFloat {
        gridContentHeight + cellHeight + 16
    }

    // MARK: - Node Width Cache (Recursive Layout)

    /// Maps each node ID to its total rendered width (sum of descendant leaf column widths).
    /// Used by the recursive header layout to determine frame widths.
    private var nodeWidthCache: [UUID: CGFloat] {
        var cache: [UUID: CGFloat] = [:]
        _ = computeNodeWidth(node: gradebook.root, cache: &cache)
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

    /// Recursively renders a tree node as a semantic header element.
    /// - Parent nodes: VStack with title bar + HStack of children
    /// - Leaf nodes: Single cell filling the available height
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
        let thisTileIsMoving = movingNodeID == node.id
        let isInMoveMode = movingNodeID != nil

        if isLeaf {
            // Leaf: single cell filling all available height
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
                    onWeightChange: { onWeightChangeFor(node.id, $0) },
                    onAddInput: { addChild(to: node.id, type: .input) },
                    onAddCalculation: { addChild(to: node.id, type: .calculation) },
                    onAddSiblingArea: { addSiblingArea(after: node.id) },
                    onOpenSettings: { settingsTarget = TileSettingsTarget(id: node.id) },
                    onAutoDistribute: { autoDistributeWeights(for: node.id) },
                    onTitleSubmit: { updateNodeTitle(nodeID: node.id, newTitle: $0) },
                    onStartMove: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            movingNodeID = movingNodeID == node.id ? nil : node.id
                        }
                    }
                )
                .allowsHitTesting(isInMoveMode ? thisTileIsMoving : true)
                .zIndex(thisTileIsMoving ? 100 : 0)
            )
        } else {
            // Parent: flat L-shape with its own title bar on top and children in the bottom-right
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
                        onWeightChange: { onWeightChangeFor(node.id, $0) },
                        onAddInput: { addChild(to: node.id, type: .input) },
                        onAddCalculation: { addChild(to: node.id, type: .calculation) },
                        onAddSiblingArea: { addSiblingArea(after: node.id) },
                        onOpenSettings: { settingsTarget = TileSettingsTarget(id: node.id) },
                        onAutoDistribute: { autoDistributeWeights(for: node.id) },
                        onTitleSubmit: { updateNodeTitle(nodeID: node.id, newTitle: $0) },
                        onStartMove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                movingNodeID = movingNodeID == node.id ? nil : node.id
                            }
                        }
                    )
                    .allowsHitTesting(isInMoveMode ? thisTileIsMoving : true)
                    .zIndex(thisTileIsMoving ? 100 : 0)
                    .frame(width: nodeWidth, height: cellHeight)

                    if remainingHeight > 0 {
                        HStack(spacing: 0) {
                            // Flat lower-left leg for nodes that expose their own summary column.
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

    // MARK: - Insertion Slots (Overlay-Based for Move Mode)

    /// Renders insertion slot indicators as an overlay with absolute positioning.
    /// Uses nodeWidthCache for x-positions and tree depth for y-positions.
    @ViewBuilder
    private func insertionSlotsOverlay(movingID: UUID, headerTotalHeight: CGFloat, widthCache: [UUID: CGFloat]) -> some View {
        let slots = computeInsertionSlotsV2(movingID: movingID, widthCache: widthCache)
        ForEach(slots) { slot in
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    executeInsertionAction(slot.action, draggedID: movingID)
                    movingNodeID = nil
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
            node: gradebook.root,
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
        if GradeTileTree.isDescendant(root: gradebook.root, ancestorID: movingID, possibleDescendantID: node.id) {
            return
        }

        let children = node.children
        let childLevel = level + 1
        let slotY = CGFloat(childLevel) * cellHeight
        let slotH = CGFloat(headerDepth - childLevel) * cellHeight
        let lineWidth: CGFloat = 28

        // x offset for children area (skip own column if present)
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
            // Build positions for each non-moving child
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

            // Before first child
            if let first = positions.first {
                slots.append(InsertionSlot(
                    id: "before-\(first.child.id.uuidString)",
                    x: first.xStart - lineWidth / 2, y: slotY,
                    slotWidth: lineWidth, slotHeight: max(slotH, cellHeight),
                    action: .beforeSibling(first.child.id),
                    isVertical: true
                ))
            }

            // After each child
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

        // Recurse into children
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.systemGroupedBackground
                .ignoresSafeArea()

            ScrollView(.vertical) {
                if #available(iOS 17.0, macOS 14.0, *) {
                    HStack(alignment: .top, spacing: 0) {
                        // Linke Seite: Name-Header + Schülerzeilen (fixiert)
                        VStack(spacing: 0) {
                            nameColumnHeader
                            nameColumnRows
                        }
                        .scaleEffect(zoomScale, anchor: .topLeading)
                        .frame(
                            width: nameColumnWidth * zoomScale,
                            height: nameColumnContentHeight * zoomScale,
                            alignment: .topLeading
                        )

                        // Rechte Seite: Ein einziges Grid für Header + Daten
                        ScrollView(.horizontal) {
                            unifiedGrid
                                .scaleEffect(zoomScale, anchor: .topLeading)
                                .frame(
                                    width: totalColumnsWidth * zoomScale,
                                    height: gridContentHeight * zoomScale,
                                    alignment: .topLeading
                                )
                        }
                        .frame(height: gridContentHeight * zoomScale, alignment: .topLeading)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                zoomScale = max(0.5, min(baseZoomScale * value.magnification, 3.0))
                            }
                            .onEnded { _ in
                                baseZoomScale = zoomScale
                            }
                    )
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        // Linke Seite: Name-Header + Schülerzeilen (fixiert)
                        VStack(spacing: 0) {
                            nameColumnHeader
                            nameColumnRows
                        }
                        .scaleEffect(zoomScale, anchor: .topLeading)
                        .frame(
                            width: nameColumnWidth * zoomScale,
                            height: nameColumnContentHeight * zoomScale,
                            alignment: .topLeading
                        )

                        // Rechte Seite: Ein einziges Grid für Header + Daten
                        ScrollView(.horizontal) {
                            unifiedGrid
                                .scaleEffect(zoomScale, anchor: .topLeading)
                                .frame(
                                    width: totalColumnsWidth * zoomScale,
                                    height: gridContentHeight * zoomScale,
                                    alignment: .topLeading
                                )
                        }
                        .frame(height: gridContentHeight * zoomScale, alignment: .topLeading)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoomScale = max(0.5, min(baseZoomScale * value, 3.0))
                            }
                            .onEnded { _ in
                                baseZoomScale = zoomScale
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.Table.cellBackground)
        }
        .navigationTitle("\(schoolClass.name) – \(schoolClass.subject)")
        .adaptiveNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Neu") {
                    showNewDialog = true
                }
            }
            #endif
        }
        .confirmationDialog("Neue Struktur", isPresented: $showNewDialog, titleVisibility: .visible) {
            Button("Standardstruktur") {
                gradebook.root = GradeTileTree.standardRoot()
                syncRowsToStructure()
            }
            Button("Manuell") {
                gradebook.root = GradeTileTree.emptyRoot()
                syncRowsToStructure()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Wähle, ob mit der Standardstruktur gestartet wird oder mit einer leeren Struktur.")
        }
        .overlay(alignment: .top) {
            if showAddStudentSheet {
                AddStudentTopPopup(
                    name: $addStudentNameDraft,
                    onCancel: {
                        showAddStudentSheet = false
                    },
                    onAdd: {
                        addStudent(named: addStudentNameDraft)
                        addStudentNameDraft = ""
                        showAddStudentSheet = false
                    }
                )
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if let target = settingsTarget,
               let node = GradeTileTree.findNode(in: gradebook.root, id: target.id) {
                // Dunkler Hintergrund zum Schließen
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            settingsTarget = nil
                        }
                    }
                
                FloatingTileSettingsPanel(
                    node: node,
                    columnWidth: Binding(
                        get: { width(for: target.id) },
                        set: { columnWidths[target.id] = $0 }
                    ),
                    showColumnWidthSlider: node.showsAsColumn,
                    minColumnWidth: minColumnWidth,
                    maxColumnWidth: maxColumnWidth,
                    onSave: { title, colorStyle in
                        var root = gradebook.root
                        GradeTileTree.updateNode(root: &root, id: target.id) { mutableNode in
                            mutableNode.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? mutableNode.title : title
                            mutableNode.colorStyle = colorStyle
                        }
                        gradebook.root = root
                    },
                    onAutoDistribute: {
                        autoDistributeWeights(for: target.id)
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            settingsTarget = nil
                        }
                    }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .overlay {
            if let target = activeInputCell {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        activeInputCell = nil
                    }

                GradeInputPopup(
                    value: $inputPopupDraft,
                    selectedCategory: $inputPopupCategory,
                    onClose: {
                        activeInputCell = nil
                    },
                    onCommit: {
                        setInputValue(inputPopupDraft, rowID: target.rowID, nodeID: target.nodeID)
                        activeInputCell = nil
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .overlay {
            if showAddStudentsPopup {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddStudentsPopup = false
                        }
                    }

                AddStudentsPopup(
                    onAddSingle: {
                        addStudentNameDraft = ""
                        showAddStudentSheet = true
                    },
                    onImportStudents: { names in
                        addStudents(names: names)
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddStudentsPopup = false
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: settingsTarget?.id)
        .animation(.easeInOut(duration: 0.2), value: activeInputCell?.id)
        .animation(.easeInOut(duration: 0.2), value: showAddStudentsPopup)
        .animation(.easeInOut(duration: 0.2), value: movingNodeID)
        .onChange(of: focusedStudentID) {
            if editingStudentID != nil, focusedStudentID == nil {
                endStudentEditing(commit: true)
            }
        }
        // Move mode: banner at the top
        .overlay(alignment: .top) {
            if let movingID = movingNodeID {
                moveBanner(for: movingID)
            }
        }
    }

    @ViewBuilder
    private func moveBanner(for movingID: UUID) -> some View {
        let title = GradeTileTree.findNode(in: gradebook.root, id: movingID)?.title ?? ""
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
                    movingNodeID = nil
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
                gradebook.rows.first(where: { $0.id == id })?.studentName ?? ""
            },
            set: { newValue in
                guard let index = gradebook.rows.firstIndex(where: { $0.id == id }) else { return }
                gradebook.rows[index].studentName = newValue
            }
        )
    }

    private func beginStudentEditing(_ studentID: UUID) {
        endStudentEditing(commit: true)
        editStudentOriginalName = gradebook.rows.first(where: { $0.id == studentID })?.studentName ?? ""
        editingStudentID = studentID
        DispatchQueue.main.async {
            focusedStudentID = studentID
        }
    }

    private func endStudentEditing(commit: Bool) {
        guard let studentID = editingStudentID else { return }
        if !commit, let index = gradebook.rows.firstIndex(where: { $0.id == studentID }) {
            gradebook.rows[index].studentName = editStudentOriginalName
        }
        focusedStudentID = nil
        editingStudentID = nil
        editStudentOriginalName = ""
    }

    private var nameColumnRows: some View {
        VStack(spacing: 0) {
            ForEach(gradebook.rows) { row in
                if editingStudentID == row.id {
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
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            beginStudentEditing(row.id)
                        }
                }
            }
            
            Button {
                showAddStudentsPopup = true
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

    /// Leaf columns in left-to-right order (matches `columns` from GradeTileTree.columns).
    private var leafColumns: [LeafColumnInfo] {
        var result: [LeafColumnInfo] = []
        collectLeaves(node: gradebook.root, result: &result)
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

    /// Execute an insertion action for the currently moving node.
    private func executeInsertionAction(_ action: InsertionAction, draggedID: UUID) {
        var root = gradebook.root
        guard let moved = GradeTileTree.removeNode(root: &root, id: draggedID) else { return }

        switch action {
        case .beforeSibling(let siblingID):
            GradeTileTree.insertAtSameLevel(root: &root, siblingID: siblingID, node: moved, after: false)
        case .afterSibling(let siblingID):
            GradeTileTree.insertAtSameLevel(root: &root, siblingID: siblingID, node: moved, after: true)
        case .appendToParent(let parentID):
            GradeTileTree.insertAsChild(root: &root, parentID: parentID, node: moved)
        }

        gradebook.root = root
        syncRowsToStructure()
    }

    /// Background color for a container rect based on level and color style.
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

    /// Corner radius for nested tile containers, decreasing with depth.
    private func tileCornerRadius(for level: Int) -> CGFloat {
        switch min(max(level, 0), 4) {
        case 0: return 12
        case 1: return 10
        case 2: return 8
        default: return 6
        }
    }

    /// The unified grid: recursive header + semantic data rows.
    private var unifiedGrid: some View {
        let leaves = leafColumns
        let totalWidth = leaves.reduce(CGFloat(0)) { $0 + $1.width }
        let headerTotalH = CGFloat(headerDepth) * cellHeight
        let cache = nodeWidthCache

        return VStack(spacing: 0) {
            // ── Header section: recursive tree-driven layout ──
            ZStack(alignment: .topLeading) {
                // Semantic header (recursive VStack/HStack)
                headerNodeView(
                    node: gradebook.root,
                    level: 0,
                    isRoot: true,
                    parentIsCalculation: false,
                    availableHeight: headerTotalH,
                    widthCache: cache
                )

                // Move-mode insertion slots (overlay on top of header)
                if let movingID = movingNodeID {
                    insertionSlotsOverlay(
                        movingID: movingID,
                        headerTotalHeight: headerTotalH,
                        widthCache: cache
                    )
                }
            }
            .frame(width: totalWidth, height: headerTotalH)

            // ── Data rows: HStack per student ──
            ForEach(gradebook.rows) { row in
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.Table.border.opacity(0.95), lineWidth: 1.4)
        }
    }

    private func onWeightChangeFor(_ nodeID: UUID, _ weight: Double) {
        updateNodeWeightAndRedistributeSiblings(nodeID: nodeID, newWeight: weight)
    }

    private func inputCell(rowID: UUID, nodeID: UUID) -> some View {
        let displayValue = inputValue(rowID: rowID, nodeID: nodeID)

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
            inputPopupDraft = displayValue
            inputPopupCategory = .numbers
            activeInputCell = GradeInputCellTarget(rowID: rowID, nodeID: nodeID)
        }
    }

    private func calculatedCell(row: StudentGradeRow, nodeID: UUID) -> some View {
        let value = GradeTileTree.findNode(in: gradebook.root, id: nodeID).flatMap {
            GradeTileTree.calculateValue(for: $0, row: row, roundingDecimals: gradebook.roundingDecimals)
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

    private func inputValue(rowID: UUID, nodeID: UUID) -> String {
        gradebook.rows.first(where: { $0.id == rowID })?.inputValues[nodeID] ?? ""
    }


    private func setInputValue(_ value: String, rowID: UUID, nodeID: UUID) {
        guard let rowIndex = gradebook.rows.firstIndex(where: { $0.id == rowID }) else { return }
        gradebook.rows[rowIndex].inputValues[nodeID] = value
    }

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
        nodeDepth(in: gradebook.root, targetID: nodeID, currentDepth: 0) ?? 0
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
            in: gradebook.root,
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

    private func syncRowsToStructure() {
        let validInputIDs = Set(columns.filter { $0.type == .input }.map { $0.nodeID })

        for index in gradebook.rows.indices {
            gradebook.rows[index].inputValues = gradebook.rows[index].inputValues.filter { validInputIDs.contains($0.key) }
            for inputID in validInputIDs where gradebook.rows[index].inputValues[inputID] == nil {
                gradebook.rows[index].inputValues[inputID] = ""
            }
        }
    }

    private func updateNodeWeight(nodeID: UUID, newWeight: Double) {
        guard (0...100).contains(newWeight) else { return }

        var root = gradebook.root
        GradeTileTree.updateNode(root: &root, id: nodeID) { node in
            node.weightPercent = roundedWeightPercent(newWeight)
        }
        gradebook.root = root
    }

    private func updateNodeWeightAndRedistributeSiblings(nodeID: UUID, newWeight: Double) {
        guard (0...100).contains(newWeight) else { return }
        guard let parentID = GradeTileTree.findParentID(root: gradebook.root, childID: nodeID) else {
            updateNodeWeight(nodeID: nodeID, newWeight: newWeight)
            return
        }
        guard let parent = GradeTileTree.findNode(in: gradebook.root, id: parentID) else { return }

        let childCount = parent.children.count
        guard childCount > 0 else { return }

        var root = gradebook.root
        GradeTileTree.updateNode(root: &root, id: parentID) { node in
            guard !node.children.isEmpty else { return }

            if node.children.count == 1 {
                node.children[0].weightPercent = 100
                node.children[0].isWeightManuallySet = false
                return
            }

            guard let targetIndex = node.children.firstIndex(where: { $0.id == nodeID }) else { return }
            node.children[targetIndex].isWeightManuallySet = true

            let otherManualTotal = node.children.indices
                .filter { $0 != targetIndex && node.children[$0].isWeightManuallySet }
                .reduce(0.0) { partialResult, index in
                    partialResult + node.children[index].weightPercent
                }
            let clampedWeight = roundedWeightPercent(min(newWeight, max(0, 100 - otherManualTotal)))
            node.children[targetIndex].weightPercent = clampedWeight

            redistributeAutomaticWeights(in: &node.children)
        }
        gradebook.root = root
    }

    private func redistributeAutomaticWeights(in children: inout [GradeTileNode]) {
        guard !children.isEmpty else { return }

        if children.count == 1 {
            children[0].weightPercent = 100
            children[0].isWeightManuallySet = false
            return
        }

        let manualIndices = children.indices.filter { children[$0].isWeightManuallySet }
        let automaticIndices = children.indices.filter { !children[$0].isWeightManuallySet }
        let manualTotal = roundedWeightPercent(
            manualIndices.reduce(0.0) { partialResult, index in
                partialResult + children[index].weightPercent
            }
        )

        guard !automaticIndices.isEmpty else { return }

        let remaining = max(0, roundedWeightPercent(100 - manualTotal))
        let equalShare = roundedWeightPercent(remaining / Double(automaticIndices.count))

        var distributedTotal = 0.0
        for automaticIndex in automaticIndices.dropLast() {
            children[automaticIndex].weightPercent = equalShare
            distributedTotal += equalShare
        }

        if let lastAutomaticIndex = automaticIndices.last {
            children[lastAutomaticIndex].weightPercent = roundedWeightPercent(remaining - distributedTotal)
        }
    }

    private func addChild(to parentID: UUID, type: GradeTileType) {
        var root = gradebook.root
        let title = type == .calculation ? "Neuer Bereich" : "Neue Notenspalte"
        
        let child = GradeTileNode(title: title, type: type, weightPercent: 0)
        GradeTileTree.insertAsChild(root: &root, parentID: parentID, node: child)
        gradebook.root = root
        
        // Gewichte automatisch gleichverteilen
        autoDistributeWeights(for: parentID)
        
        syncRowsToStructure()
    }

    private func addSiblingArea(after siblingID: UUID) {
        guard let parentID = GradeTileTree.findParentID(root: gradebook.root, childID: siblingID) else { return }
        
        var root = gradebook.root
        let sibling = GradeTileNode(title: "Neuer Bereich", type: .calculation, weightPercent: 0)
        GradeTileTree.insertAtSameLevel(root: &root, siblingID: siblingID, node: sibling, after: true)
        gradebook.root = root
        
        // Gewichte im gemeinsamen Elternknoten gleichverteilen
        autoDistributeWeights(for: parentID)
        
        syncRowsToStructure()
    }

    private func autoDistributeWeights(for parentID: UUID) {
        guard let parent = GradeTileTree.findNode(in: gradebook.root, id: parentID) else { return }
        let count = parent.children.count
        guard count > 0 else { return }

        var root = gradebook.root
        GradeTileTree.updateNode(root: &root, id: parentID) { node in
            guard !node.children.isEmpty else { return }
            for index in node.children.indices {
                node.children[index].isWeightManuallySet = false
            }
            redistributeAutomaticWeights(in: &node.children)
        }
        gradebook.root = root
    }

    private func roundedWeightPercent(_ value: Double) -> Double {
        let factor = 100.0
        return (value * factor).rounded() / factor
    }

    private func updateNodeTitle(nodeID: UUID, newTitle: String) {
        var root = gradebook.root
        GradeTileTree.updateNode(root: &root, id: nodeID) { node in
            node.title = newTitle
        }
        gradebook.root = root
    }
    
    private func width(for nodeID: UUID) -> CGFloat {
        columnWidths[nodeID] ?? preferredWidth(for: nodeID)
    }

    private func preferredWidth(for nodeID: UUID) -> CGFloat {
        guard let node = GradeTileTree.findNode(in: gradebook.root, id: nodeID) else {
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
        hasCalculationParent(in: gradebook.root, targetID: nodeID, parentIsCalculation: false) ?? false
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
    
    private func addStudent(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let inputIDs = Set(columns.filter { $0.type == .input }.map { $0.nodeID })
        var values: [UUID: String] = [:]
        for inputID in inputIDs {
            values[inputID] = ""
        }
        
        gradebook.rows.append(StudentGradeRow(studentName: trimmed, inputValues: values))
    }

    private func addStudents(names: [String]) {
        let inputIDs = Set(columns.filter { $0.type == .input }.map { $0.nodeID })

        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            var values: [UUID: String] = [:]
            for inputID in inputIDs {
                values[inputID] = ""
            }

            gradebook.rows.append(StudentGradeRow(studentName: trimmed, inputValues: values))
        }
    }


}

struct GradeInputCellTarget: Identifiable, Equatable {
    let rowID: UUID
    let nodeID: UUID

    var id: String {
        "\(rowID.uuidString)-\(nodeID.uuidString)"
    }
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
        // Smileys
        EmojiOption(id: "happy", emoji: "", symbol: "face.smiling.fill", label: "Zufrieden"),
        EmojiOption(id: "sad", emoji: "", symbol: "face.dashed", label: "Unzufrieden"),
        // Bewertung positiv
        EmojiOption(id: "greenCheck", emoji: "", symbol: "checkmark.circle.fill", label: "Erledigt"),
        EmojiOption(id: "thumbsUp", emoji: "", symbol: "hand.thumbsup.fill", label: "Gut"),
        EmojiOption(id: "star", emoji: "", symbol: "star.fill", label: "Sehr gut"),
        EmojiOption(id: "trophy", emoji: "", symbol: "trophy.fill", label: "Ausgezeichnet"),
        // Bewertung negativ
        EmojiOption(id: "redCross", emoji: "", symbol: "xmark.circle.fill", label: "Nicht erledigt"),
        EmojiOption(id: "thumbsDown", emoji: "", symbol: "hand.thumbsdown.fill", label: "Mangelhaft"),
        EmojiOption(id: "warn", emoji: "", symbol: "exclamationmark.triangle.fill", label: "Achtung"),
        EmojiOption(id: "minus", emoji: "", symbol: "minus.circle.fill", label: "Fehlend"),
        // Status / Organisation
        EmojiOption(id: "clock", emoji: "", symbol: "clock.fill", label: "Ausstehend"),
        EmojiOption(id: "absent", emoji: "", symbol: "person.slash.fill", label: "Abwesend"),
        EmojiOption(id: "excused", emoji: "", symbol: "envelope.fill", label: "Entschuldigt"),
        EmojiOption(id: "homework", emoji: "", symbol: "doc.text.fill", label: "Hausaufgabe"),
        // Unterricht
        EmojiOption(id: "oral", emoji: "", symbol: "bubble.left.fill", label: "Mündlich"),
        EmojiOption(id: "note", emoji: "", symbol: "pencil.circle.fill", label: "Notiz"),
        EmojiOption(id: "idea", emoji: "", symbol: "lightbulb.fill", label: "Idee"),
        EmojiOption(id: "eye", emoji: "", symbol: "eye.fill", label: "Beobachtung")
    ]
}

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

/// Info about a single leaf column for width computation.
private struct LeafColumnInfo {
    let nodeID: UUID
    let width: CGFloat
}

/// An insertion slot shown between siblings (or at the edges) when in move-mode.
/// The user taps a slot to place the moving node at that position.
private struct InsertionSlot: Identifiable {
    let id: String            // unique key
    let x: CGFloat            // x position in the grid
    let y: CGFloat            // y position in the grid
    let slotWidth: CGFloat    // how wide the indicator should be
    let slotHeight: CGFloat   // how tall the indicator should be (full column height for vertical lines)
    let action: InsertionAction
    let isVertical: Bool      // true = vertical line between columns, false = horizontal
}

private enum InsertionAction {
    /// Insert before the given sibling
    case beforeSibling(UUID)
    /// Insert after the given sibling
    case afterSibling(UUID)
    /// Append as last child of the given parent
    case appendToParent(UUID)
}

// MARK: - Header Tile View (Grid Cell Content)

struct HeaderTileView: View {
    let node: GradeTileNode
    let isRoot: Bool
    let level: Int
    let parentIsCalculation: Bool
    let width: CGFloat
    let height: CGFloat
    let isLeaf: Bool
    let showWeightWarning: Bool
    /// True when this tile is the one being moved
    let isMoving: Bool

    let onWeightChange: (Double) -> Void
    let onAddInput: () -> Void
    let onAddCalculation: () -> Void
    let onAddSiblingArea: () -> Void
    let onOpenSettings: () -> Void
    let onAutoDistribute: () -> Void
    let onTitleSubmit: (String) -> Void
    let onStartMove: () -> Void
    
    @State private var showCustomWeightSheet = false
    @State private var customWeightText = ""
    @State private var isEditing = false
    @State private var editingTitle = ""
    @FocusState private var isTitleFieldFocused: Bool

    /// Corner radius for leaf tiles, decreasing with depth.
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
            // Content area pinned to top
            HStack(spacing: 6) {
                // Move handle — tap to enter move mode
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
        // Leaf cells get a rounded border; parent title bars have no separator (container border suffices)
        .overlay {
            if isLeaf {
                RoundedRectangle(cornerRadius: leafCornerRadius, style: .continuous)
                    .strokeBorder(Color.Table.border.opacity(0.9), lineWidth: 0.8)
            }
        }
        // Move mode: lifted appearance for the tile being moved
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

    private var tileBackground: Color {
        let normalizedLevel = min(max(level, 0), 4)
        switch node.colorStyle {
        case .automatic:
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

struct TileSettingsTarget: Identifiable {
    let id: UUID
}

struct AddStudentTopPopup: View {
    @Binding var name: String
    let onCancel: () -> Void
    let onAdd: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let popupWidth = min(700, geometry.size.width * 0.66)

            VStack(alignment: .leading, spacing: 10) {
                Text("Schüler hinzufügen")
                    .font(.system(size: 15, weight: .semibold))

                TextField("z. B. Anna Müller", text: $name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Abbrechen", action: onCancel)
                        .buttonStyle(.bordered)

                    Spacer()

                    Button("Hinzufügen", action: onAdd)
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(22)
            .background(Color.secondarySystemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 25, y: 10)
            .frame(width: popupWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Add Students Popup (CSV Import)

struct AddStudentsPopup: View {
    let onAddSingle: () -> Void
    let onImportStudents: ([String]) -> Void
    let onClose: () -> Void

    @State private var showFilePicker = false
    @State private var csvPreviewNames: [String] = []
    @State private var showPreview = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            let popupWidth = min(500, geometry.size.width * 0.7)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Schüler hinzufügen")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Spacer()

                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)

                if showPreview {
                    csvPreviewView
                } else {
                    optionsView
                }
            }
            .background(Color.secondarySystemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.15), radius: 30, y: 12)
            .frame(width: popupWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private var optionsView: some View {
        VStack(spacing: 12) {
            // Einzeln hinzufügen
            Button {
                onClose()
                onAddSingle()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Einzeln hinzufügen")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Einen Schüler manuell eingeben")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            // CSV Import
            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                        .frame(width: 40, height: 40)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CSV-Datei importieren")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Klassenliste aus einer .csv-Datei laden")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private var csvPreviewView: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(csvPreviewNames.count) Schüler erkannt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(csvPreviewNames.enumerated()), id: \.offset) { index, name in
                        HStack {
                            Text("\(index + 1).")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            Text(name)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        if index < csvPreviewNames.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                }
            }
            .frame(maxHeight: 250)

            HStack(spacing: 12) {
                Button("Abbrechen") {
                    showPreview = false
                    csvPreviewNames = []
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Alle importieren") {
                    onImportStudents(csvPreviewNames)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Zugriff auf die Datei wurde verweigert."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let names = parseCSV(content)
                if names.isEmpty {
                    errorMessage = "Keine Schülernamen in der Datei gefunden."
                } else {
                    errorMessage = nil
                    csvPreviewNames = names
                    showPreview = true
                }
            } catch {
                errorMessage = "Datei konnte nicht gelesen werden."
            }

        case .failure:
            errorMessage = "Datei konnte nicht geöffnet werden."
        }
    }

    private func parseCSV(_ content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var names: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let columns = trimmed.components(separatedBy: CharacterSet(charactersIn: ",;\t"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }

            // Erste Zeile als Header überspringen, wenn sie typische Header-Begriffe enthält
            if index == 0 {
                let headerKeywords = ["name", "vorname", "nachname", "schüler", "schuelername", "firstname", "lastname", "student"]
                let lowerLine = trimmed.lowercased()
                if headerKeywords.contains(where: { lowerLine.contains($0) }) {
                    continue
                }
            }

            // Heuristik: Wenn 2+ Spalten, versuche Nachname + Vorname zusammenzufügen
            if columns.count >= 2 {
                let first = columns[0]
                let second = columns[1]

                if !first.isEmpty && !second.isEmpty {
                    // Prüfe ob erste Spalte eine Nummer ist (z.B. laufende Nr.)
                    if Int(first) != nil {
                        // Erste Spalte ist eine Nummer -> Name ab Spalte 2
                        if columns.count >= 3 && !columns[2].isEmpty {
                            names.append("\(second) \(columns[2])")
                        } else {
                            names.append(second)
                        }
                    } else {
                        names.append("\(first) \(second)")
                    }
                } else if !first.isEmpty {
                    names.append(first)
                }
            } else if columns.count == 1 && !columns[0].isEmpty {
                names.append(columns[0])
            }
        }

        return names
    }
}

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
            // Ziehleiste
            dragHandle
            
            Divider()
            
            // Inhalt
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Titel
                    sectionView(title: "Titel") {
                        TextField("Titel", text: $titleText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                onSave(titleText, colorStyle)
                            }
                    }
                    
                    // Spaltenbreite
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
                    
                    // Farbpalette
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
                    
                    // Gewichtung
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
                    
                    // Sichern-Button
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



private enum MockClassData {
    static func seed() -> (classes: [SchoolClass], gradebooksByClassID: [UUID: ClassGradebooksState]) {
        let classes = [
            SchoolClass(name: "10b", subject: "Deutsch", schoolYear: "2025/2026"),
            SchoolClass(name: "5a", subject: "Mathematik", schoolYear: "2025/2026")
        ]

        let class10bRows = [
            StudentGradeRow(studentName: "Anna Müller"),
            StudentGradeRow(studentName: "Ben Schmidt"),
            StudentGradeRow(studentName: "Clara Weber"),
            StudentGradeRow(studentName: "David Fischer"),
            StudentGradeRow(studentName: "Emilia Wagner"),
            StudentGradeRow(studentName: "Felix Neumann"),
            StudentGradeRow(studentName: "Greta Hoffmann"),
            StudentGradeRow(studentName: "Henry Becker")
        ]

        let class5aRows = [
            StudentGradeRow(studentName: "Lina Koch"),
            StudentGradeRow(studentName: "Noah Richter"),
            StudentGradeRow(studentName: "Mia Wolf"),
            StudentGradeRow(studentName: "Paul Krüger"),
            StudentGradeRow(studentName: "Sofia Hartmann"),
            StudentGradeRow(studentName: "Tom Schulz")
        ]

        let state10b = ClassGradebookState(root: GradeTileTree.standardRoot(), rows: class10bRows)
        let state5a = ClassGradebookState(root: GradeTileTree.standardRoot(), rows: class5aRows)

        let tab10b = GradebookTabState(schoolYear: classes[0].schoolYear, gradebook: state10b)
        let tab5a = GradebookTabState(schoolYear: classes[1].schoolYear, gradebook: state5a)

        var gradebooksByClassID: [UUID: ClassGradebooksState] = [
            classes[0].id: ClassGradebooksState(tabs: [tab10b], selectedTabID: tab10b.id),
            classes[1].id: ClassGradebooksState(tabs: [tab5a], selectedTabID: tab5a.id)
        ]

        for id in gradebooksByClassID.keys {
            if var classState = gradebooksByClassID[id] {
                for tabIndex in classState.tabs.indices {
                    let inputIDs = Set(GradeTileTree.columns(from: classState.tabs[tabIndex].gradebook.root).filter { $0.type == .input }.map { $0.nodeID })
                    for rowIndex in classState.tabs[tabIndex].gradebook.rows.indices {
                        for inputID in inputIDs {
                            classState.tabs[tabIndex].gradebook.rows[rowIndex].inputValues[inputID] = ""
                        }
                    }
                }
                gradebooksByClassID[id] = classState
            }
        }

        return (classes, gradebooksByClassID)
    }
}

#Preview("Klassen") {
    NavigationStack {
        GradeBookMainView()
    }
}




