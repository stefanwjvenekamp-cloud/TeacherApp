import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension GradebookDetailView {
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

    func headerTileColorOwner(for node: GradeTileNode) -> GradeTileNode? {
        node.colorStyle == .automatic ? nil : node
    }

    func containerColorOwner(for node: GradeTileNode) -> GradeTileNode? {
        node.colorStyle == .automatic ? nil : node
    }

    func dataColorOwner(for leafNodeID: UUID) -> GradeTileNode? {
        guard visibleColumnIDs.contains(leafNodeID) else {
            return nil
        }

        guard let node = GradeTileTree.findNode(in: viewModel.root, id: leafNodeID) else {
            return nil
        }

        return node.colorStyle == .automatic ? nil : node
    }

    func containerBackground(for node: GradeTileNode, level: Int) -> Color {
        let colorOwner = containerColorOwner(for: node)
        let normalizedLevel = min(max(level, 0), 4)
        switch colorOwner?.colorStyle ?? .automatic {
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

    var gridHeaderView: some View {
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

    var gridRowsView: some View {
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

    func depth(of node: GradeTileNode) -> Int {
        if node.children.isEmpty { return 1 }
        return 1 + (node.children.map(depth(of:)).max() ?? 0)
    }
    
    private func columnBackground(for nodeID: UUID, isCalculated: Bool) -> Color {
        let depth = nodeDepth(for: nodeID)
        let normalizedDepth = min(max(depth, 0), 4)
        let style = dataColorOwner(for: nodeID)?.colorStyle ?? .automatic

        if style != .automatic {
            let tintedBackground = columnTintColor(for: style, isCalculated: isCalculated)
            switch normalizedDepth {
            case 0:
                return tintedBackground
            case 1:
                return tintedBackground.opacity(0.94)
            default:
                return tintedBackground.opacity(0.88)
            }
        }

        if isCalculated {
            switch normalizedDepth {
            case 0:
                return Color.Table.hover
            case 1:
                return Color.Table.hover.opacity(0.92)
            default:
                return Color.Table.hover.opacity(0.84)
            }
        } else {
            switch normalizedDepth {
            case 0:
                return Color.Table.cellBackground
            case 1:
                return Color.Table.cellBackground.opacity(0.97)
            default:
                return Color.Table.cellBackground.opacity(0.94)
            }
        }
    }

    private func columnTintColor(for style: GradeTileColorStyle, isCalculated: Bool) -> Color {
        let opacity: Double = isCalculated ? 0.72 : 0.58

        switch style {
        case .automatic:
            return isCalculated ? Color.Table.hover : Color.Table.cellBackground
        case .slate:
            return Color(red: 0.92, green: 0.93, blue: 0.95).opacity(opacity)
        case .blue:
            return Color(red: 0.88, green: 0.93, blue: 0.99).opacity(opacity)
        case .green:
            return Color(red: 0.89, green: 0.96, blue: 0.91).opacity(opacity)
        case .orange:
            return Color(red: 0.99, green: 0.93, blue: 0.86).opacity(opacity)
        case .red:
            return Color(red: 0.99, green: 0.90, blue: 0.90).opacity(opacity)
        }
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
    
    func width(for nodeID: UUID) -> CGFloat {
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

    func requestDeleteNode(for id: UUID) {
        guard viewModel.root.id != id else { return }
        viewModel.pendingDeleteNodeID = id
        viewModel.showDeleteNodeDialog = true
    }

    func requestDeleteStudent(id: UUID) {
        viewModel.pendingDeleteStudentID = id
        viewModel.showDeleteStudentDialog = true
    }
}
