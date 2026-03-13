import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct GradebookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let schoolClass: SchoolClass
    let tab: GradebookTabEntity
    @State var viewModel: GradebookDetailViewModel

    @FocusState var focusedStudentID: UUID?

    let nameColumnWidth: CGFloat = 180
    let defaultColumnWidth: CGFloat = 90
    let minColumnWidth: CGFloat = 75
    let maxColumnWidth: CGFloat = 300
    let cellHeight: CGFloat = 38
    let headerGap: CGFloat = 0

    init(schoolClass: SchoolClass, tab: GradebookTabEntity, context: ModelContext) {
        self.schoolClass = schoolClass
        self.tab = tab
        self._viewModel = State(initialValue: GradebookDetailViewModel(
            schoolClass: schoolClass, tab: tab, context: context
        ))
    }

    var body: some View {
        gradebookDetailContent
    }

    var columns: [GradebookColumn] {
        viewModel.columns
    }

    var visibleColumnIDs: Set<UUID> {
        Set(columns.map(\.nodeID))
    }

    var headerDepth: Int {
        max(depth(of: viewModel.root), 1)
    }

    var headerHeight: CGFloat {
        CGFloat(headerDepth) * cellHeight + CGFloat(max(headerDepth - 1, 0)) * headerGap
    }

    var totalColumnsWidth: CGFloat {
        columns.reduce(CGFloat(0)) { $0 + width(for: $1.nodeID) }
    }

    var gridContentHeight: CGFloat {
        headerHeight + CGFloat(viewModel.rows.count) * cellHeight
    }

    var gridRowsHeight: CGFloat {
        CGFloat(viewModel.rows.count) * cellHeight
    }

    var nameColumnContentHeight: CGFloat {
        gridContentHeight + cellHeight + 16
    }

    var nameColumnRowsHeight: CGFloat {
        nameColumnContentHeight - headerHeight
    }

    // MARK: - Node Width Cache (Recursive Layout)

    var nodeWidthCache: [UUID: CGFloat] {
        var cache: [UUID: CGFloat] = [:]
        _ = computeNodeWidth(node: viewModel.root, cache: &cache)
        return cache
    }

    @discardableResult
    func computeNodeWidth(node: GradeTileNode, cache: inout [UUID: CGFloat]) -> CGFloat {
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

    func headerNodeView(
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
        let canMergeSiblings = canMergeSiblings(for: node)

        if isLeaf {
            return AnyView(
                HeaderTileView(
                    node: node,
                    isRoot: isRoot,
                    level: level,
                    parentIsCalculation: parentIsCalculation,
                    width: nodeWidth,
                    height: availableHeight,
                    colorFillWidth: nodeWidth,
                    tileColorStyle: headerTileColorOwner(for: node)?.colorStyle ?? .automatic,
                    isLeaf: true,
                    showWeightWarning: false,
                    isMoving: thisTileIsMoving,
                    onWeightChange: { viewModel.updateWeightAndRedistribute(nodeID: node.id, newWeight: $0) },
                    onAddInput: { viewModel.addChild(to: node.id, type: .input) },
                    onAddCalculation: { viewModel.addChild(to: node.id, type: .calculation) },
                    onAddSiblingArea: { viewModel.addSiblingArea(after: node.id) },
                    canMergeSiblings: canMergeSiblings,
                    onMergeSiblings: { mergeSiblings(for: node) },
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
                        colorFillWidth: nodeWidth,
                        tileColorStyle: headerTileColorOwner(for: node)?.colorStyle ?? .automatic,
                        isLeaf: false,
                        showWeightWarning: node.type == .calculation && !GradeTileTree.isWeightValid(for: node),
                        isMoving: thisTileIsMoving,
                        onWeightChange: { viewModel.updateWeightAndRedistribute(nodeID: node.id, newWeight: $0) },
                        onAddInput: { viewModel.addChild(to: node.id, type: .input) },
                        onAddCalculation: { viewModel.addChild(to: node.id, type: .calculation) },
                        onAddSiblingArea: { viewModel.addSiblingArea(after: node.id) },
                        canMergeSiblings: canMergeSiblings,
                        onMergeSiblings: { mergeSiblings(for: node) },
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

    private func canMergeSiblings(for node: GradeTileNode) -> Bool {
        guard node.type == .calculation,
              let siblingIDs = siblingNodeIDs(for: node.id)
        else {
            return false
        }
        return siblingIDs.count >= 2
    }

    private func mergeSiblings(for node: GradeTileNode) {
        guard let siblingIDs = siblingNodeIDs(for: node.id), siblingIDs.count >= 2 else { return }
        viewModel.mergeSiblingNodesUnderNewParent(nodeIDs: siblingIDs)
    }

    private func siblingNodeIDs(for nodeID: UUID) -> [UUID]? {
        guard let parentID = GradeTileTree.findParentID(root: viewModel.root, childID: nodeID),
              let parentNode = GradeTileTree.findNode(in: viewModel.root, id: parentID)
        else {
            return nil
        }
        return parentNode.children.map(\.id)
    }

    // MARK: - Insertion Slots

    @ViewBuilder
    func insertionSlotsOverlay(movingID: UUID, headerTotalHeight: CGFloat, widthCache: [UUID: CGFloat]) -> some View {
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

    func computeInsertionSlotsV2(movingID: UUID, widthCache: [UUID: CGFloat]) -> [InsertionSlot] {
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

    func collectInsertionSlotsV2(
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


}
