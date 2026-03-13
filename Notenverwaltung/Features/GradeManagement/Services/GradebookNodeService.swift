import Foundation
import SwiftData

@MainActor
enum GradebookNodeService {

    /// Add a child node to a parent and auto-distribute weights.
    static func addChild(
        to parentID: UUID,
        type: GradeTileType,
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        var root = root
        let title = type == .calculation ? "Neuer Bereich" : "Neue Notenspalte"
        let child = GradeTileNode(title: title, type: type, weightPercent: 0)
        GradeTileTree.insertAsChild(root: &root, parentID: parentID, node: child)
        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        syncCellValuesToStructure(root: root, tab: tab, context: context)
        root = autoDistributeWeights(for: parentID, root: root, tab: tab, context: context)
        syncCellValuesToStructure(root: root, tab: tab, context: context)
        return root
    }

    /// Add a sibling calculation area after the given node.
    static func addSiblingArea(
        after siblingID: UUID,
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        guard let parentID = GradeTileTree.findParentID(root: root, childID: siblingID) else { return root }
        var root = root
        let sibling = GradeTileNode(title: "Neuer Bereich", type: .calculation, weightPercent: 0)
        GradeTileTree.insertAtSameLevel(root: &root, siblingID: siblingID, node: sibling, after: true)
        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        syncCellValuesToStructure(root: root, tab: tab, context: context)
        root = autoDistributeWeights(for: parentID, root: root, tab: tab, context: context)
        syncCellValuesToStructure(root: root, tab: tab, context: context)
        return root
    }

    /// Merge sibling nodes under a newly created calculation parent.
    static func mergeSiblingNodesUnderNewParent(
        nodeIDs: [UUID],
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        guard nodeIDs.count >= 2 else { return root }

        var seenIDs = Set<UUID>()
        for nodeID in nodeIDs where !seenIDs.insert(nodeID).inserted {
            return root
        }

        guard let firstNodeID = nodeIDs.first,
              firstNodeID != root.id,
              let parentID = GradeTileTree.findParentID(root: root, childID: firstNodeID),
              let parentNode = GradeTileTree.findNode(in: root, id: parentID)
        else {
            return root
        }

        for nodeID in nodeIDs {
            guard nodeID != root.id,
                  GradeTileTree.findNode(in: root, id: nodeID) != nil,
                  GradeTileTree.findParentID(root: root, childID: nodeID) == parentID
            else {
                return root
            }
        }

        let mergedNodeIDs = Set(nodeIDs)
        let mergedChildren = parentNode.children.filter { mergedNodeIDs.contains($0.id) }
        guard mergedChildren.count == nodeIDs.count else { return root }

        let newParent = GradeTileNode(
            title: "Neuer Oberbereich",
            type: .calculation,
            weightPercent: 0,
            children: mergedChildren
        )

        var updatedRoot = root
        GradeTileTree.updateNode(root: &updatedRoot, id: parentID) { parent in
            var updatedChildren: [GradeTileNode] = []
            var insertedParent = false

            for child in parent.children {
                if mergedNodeIDs.contains(child.id) {
                    if !insertedParent {
                        updatedChildren.append(newParent)
                        insertedParent = true
                    }
                    continue
                }
                updatedChildren.append(child)
            }

            parent.children = updatedChildren
        }

        GradebookRepository.replaceNodeTree(for: tab, root: updatedRoot, in: context)
        updatedRoot = autoDistributeWeights(for: newParent.id, root: updatedRoot, tab: tab, context: context)
        updatedRoot = autoDistributeWeights(for: parentID, root: updatedRoot, tab: tab, context: context)
        syncCellValuesToStructure(root: updatedRoot, tab: tab, context: context)
        return updatedRoot
    }

    /// Delete a node and clean up cell values for removed input nodes.
    static func deleteNode(
        id: UUID,
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        guard root.id != id else { return root }

        let parentID = GradeTileTree.findParentID(root: root, childID: id)
        let inputIDsToRemove = collectInputNodeIDs(in: root, nodeID: id)
        var root = root
        guard GradeTileTree.removeNode(root: &root, id: id) != nil else { return root }

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)

        if !inputIDsToRemove.isEmpty {
            GradebookRepository.removeCellValues(for: inputIDsToRemove, in: tab, context: context)
        }

        if let parentID {
            root = autoDistributeWeights(for: parentID, root: root, tab: tab, context: context)
        }

        syncCellValuesToStructure(root: root, tab: tab, context: context)
        return root
    }

    /// Update the weight of a single node and redistribute sibling weights.
    static func updateWeightAndRedistribute(
        nodeID: UUID,
        newWeight: Double,
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        guard (0...100).contains(newWeight) else { return root }

        guard let parentID = GradeTileTree.findParentID(root: root, childID: nodeID) else {
            return updateWeight(nodeID: nodeID, newWeight: newWeight, root: root, tab: tab, context: context)
        }
        guard GradeTileTree.findNode(in: root, id: parentID) != nil else { return root }

        var root = root
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
                .reduce(0.0) { $0 + node.children[$1].weightPercent }
            let clampedWeight = roundedWeightPercent(min(newWeight, max(0, 100 - otherManualTotal)))
            node.children[targetIndex].weightPercent = clampedWeight

            redistributeAutomaticWeights(in: &node.children)
        }
        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        return root
    }

    /// Auto-distribute weights equally among children of the given parent.
    @discardableResult
    static func autoDistributeWeights(
        for parentID: UUID,
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        guard GradeTileTree.findNode(in: root, id: parentID) != nil else { return root }
        var root = root
        GradeTileTree.updateNode(root: &root, id: parentID) { node in
            guard !node.children.isEmpty else { return }
            for index in node.children.indices {
                node.children[index].isWeightManuallySet = false
            }
            redistributeAutomaticWeights(in: &node.children)
        }
        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        return root
    }

    /// Update the title of a node.
    static func updateTitle(
        nodeID: UUID,
        newTitle: String,
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        var root = root
        GradeTileTree.updateNode(root: &root, id: nodeID) { node in
            node.title = newTitle
        }
        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        return root
    }

    /// Execute a drag-and-drop insertion action for a moved node.
    static func executeInsertionAction(
        _ action: InsertionAction,
        draggedID: UUID,
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        var root = root
        guard let moved = GradeTileTree.removeNode(root: &root, id: draggedID) else { return root }

        switch action {
        case .beforeSibling(let siblingID):
            GradeTileTree.insertAtSameLevel(root: &root, siblingID: siblingID, node: moved, after: false)
        case .afterSibling(let siblingID):
            GradeTileTree.insertAtSameLevel(root: &root, siblingID: siblingID, node: moved, after: true)
        case .appendToParent(let parentID):
            GradeTileTree.insertAsChild(root: &root, parentID: parentID, node: moved)
        }

        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        syncCellValuesToStructure(root: root, tab: tab, context: context)
        return root
    }

    // MARK: - Private Helpers

    private static func updateWeight(
        nodeID: UUID,
        newWeight: Double,
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) -> GradeTileNode {
        guard (0...100).contains(newWeight) else { return root }
        var root = root
        GradeTileTree.updateNode(root: &root, id: nodeID) { node in
            node.weightPercent = roundedWeightPercent(newWeight)
        }
        GradebookRepository.replaceNodeTree(for: tab, root: root, in: context)
        return root
    }

    static func redistributeAutomaticWeights(in children: inout [GradeTileNode]) {
        guard !children.isEmpty else { return }

        if children.count == 1 {
            children[0].weightPercent = 100
            children[0].isWeightManuallySet = false
            return
        }

        let manualIndices = children.indices.filter { children[$0].isWeightManuallySet }
        let automaticIndices = children.indices.filter { !children[$0].isWeightManuallySet }
        let manualTotal = roundedWeightPercent(
            manualIndices.reduce(0.0) { $0 + children[$1].weightPercent }
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

    static func roundedWeightPercent(_ value: Double) -> Double {
        let factor = 100.0
        return (value * factor).rounded() / factor
    }

    private static func collectInputNodeIDs(in root: GradeTileNode, nodeID: UUID) -> Set<UUID> {
        guard let node = GradeTileTree.findNode(in: root, id: nodeID) else { return [] }
        return collectInputIDs(node)
    }

    private static func collectInputIDs(_ node: GradeTileNode) -> Set<UUID> {
        var result: Set<UUID> = []
        if node.type == .input {
            result.insert(node.id)
        }
        for child in node.children {
            result.formUnion(collectInputIDs(child))
        }
        return result
    }

    private static func syncCellValuesToStructure(
        root: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) {
        let validInputIDs = Set(
            GradeTileTree.columns(from: root)
                .filter { $0.type == .input }
                .map { $0.nodeID }
        )
        GradebookRepository.ensureCellValues(
            for: tab,
            rowIDs: GradebookRepository.rows(for: tab).map(\.id),
            nodeIDs: validInputIDs,
            context: context
        )
    }
}
