import Foundation
import SwiftData

@MainActor
enum GradebookTreeService {
    static func makeTree(from rootEntity: GradebookNodeEntity) -> GradeTileNode {
        let children = rootEntity.children
            .sorted(by: sortNodes)
            .map(makeTree(from:))

        return GradeTileNode(
            id: rootEntity.id,
            title: rootEntity.title,
            type: rootEntity.nodeType,
            weightPercent: rootEntity.weightPercent,
            isWeightManuallySet: rootEntity.isWeightManuallySet,
            showsAsColumn: rootEntity.showsAsColumn,
            colorStyle: rootEntity.colorStyle,
            children: children
        )
    }

    static func makeEntityTree(
        from root: GradeTileNode,
        tab: GradebookTabEntity,
        parent: GradebookNodeEntity? = nil,
        sortOrder: Int = 0
    ) -> GradebookNodeEntity {
        let entity = GradebookNodeEntity(
            id: root.id,
            title: root.title,
            nodeType: root.type,
            weightPercent: root.weightPercent,
            isWeightManuallySet: root.isWeightManuallySet,
            showsAsColumn: root.showsAsColumn,
            colorStyle: root.colorStyle,
            sortOrder: sortOrder,
            tab: tab,
            parent: parent
        )

        entity.children = root.children.enumerated().map { index, child in
            makeEntityTree(from: child, tab: tab, parent: entity, sortOrder: index)
        }

        return entity
    }

    /// Updates an existing entity tree in-place from a `GradeTileNode` tree.
    /// Children are matched by UUID: existing ones are updated recursively,
    /// new ones are inserted, and removed ones are deleted.
    /// This preserves `GradebookCellValueEntity` relationships on nodes that still exist.
    static func updateEntityTree(
        existing entity: GradebookNodeEntity,
        from node: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext
    ) {
        // Update scalar properties
        entity.title = node.title
        entity.nodeType = node.type
        entity.weightPercent = node.weightPercent
        entity.isWeightManuallySet = node.isWeightManuallySet
        entity.showsAsColumn = node.showsAsColumn
        entity.colorStyle = node.colorStyle

        // Build lookup of existing children by UUID
        let existingChildrenByID = Dictionary(uniqueKeysWithValues: entity.children.map { ($0.id, $0) })
        let newChildIDs = Set(node.children.map(\.id))

        // Delete children that no longer exist in the node tree
        for child in entity.children where !newChildIDs.contains(child.id) {
            context.delete(child)
        }

        // Update or insert children, preserving sort order
        var updatedChildren: [GradebookNodeEntity] = []
        for (index, childNode) in node.children.enumerated() {
            if let existingChild = existingChildrenByID[childNode.id] {
                existingChild.sortOrder = index
                updateEntityTree(existing: existingChild, from: childNode, tab: tab, context: context)
                updatedChildren.append(existingChild)
            } else {
                let newChild = makeEntityTree(from: childNode, tab: tab, parent: entity, sortOrder: index)
                context.insert(newChild)
                updatedChildren.append(newChild)
            }
        }

        entity.children = updatedChildren
    }

    static func sortNodes(_ lhs: GradebookNodeEntity, _ rhs: GradebookNodeEntity) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return lhs.sortOrder < rhs.sortOrder
    }
}
