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
            isTechnicalRoot: rootEntity.isTechnicalRoot,
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
            isTechnicalRoot: root.isTechnicalRoot,
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
        var reusableEntitiesByID = Dictionary(
            uniqueKeysWithValues: descendantEntities(of: entity).map { ($0.id, $0) }
        )
        updateEntityTree(
            existing: entity,
            from: node,
            tab: tab,
            context: context,
            reusableEntitiesByID: &reusableEntitiesByID
        )

        for obsoleteEntity in reusableEntitiesByID.values {
            context.delete(obsoleteEntity)
        }
    }

    static func sortNodes(_ lhs: GradebookNodeEntity, _ rhs: GradebookNodeEntity) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return lhs.sortOrder < rhs.sortOrder
    }

    private static func descendantEntities(of entity: GradebookNodeEntity) -> [GradebookNodeEntity] {
        var result: [GradebookNodeEntity] = []
        for child in entity.children {
            result.append(child)
            result.append(contentsOf: descendantEntities(of: child))
        }
        return result
    }

    private static func updateEntityTree(
        existing entity: GradebookNodeEntity,
        from node: GradeTileNode,
        tab: GradebookTabEntity,
        context: ModelContext,
        reusableEntitiesByID: inout [UUID: GradebookNodeEntity]
    ) {
        entity.title = node.title
        entity.nodeType = node.type
        entity.weightPercent = node.weightPercent
        entity.isWeightManuallySet = node.isWeightManuallySet
        entity.showsAsColumn = node.showsAsColumn
        entity.isTechnicalRoot = node.isTechnicalRoot
        entity.colorStyle = node.colorStyle

        let existingChildrenByID = Dictionary(
            entity.children.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var updatedChildren: [GradebookNodeEntity] = []

        for (index, childNode) in node.children.enumerated() {
            let childEntity: GradebookNodeEntity
            if let existingChild = existingChildrenByID[childNode.id] {
                childEntity = existingChild
            } else if let reusedChild = reusableEntitiesByID[childNode.id] {
                childEntity = reusedChild
            } else {
                childEntity = GradebookNodeEntity(
                    id: childNode.id,
                    title: childNode.title,
                    nodeType: childNode.type,
                    weightPercent: childNode.weightPercent,
                    isWeightManuallySet: childNode.isWeightManuallySet,
                    showsAsColumn: childNode.showsAsColumn,
                    isTechnicalRoot: childNode.isTechnicalRoot,
                    colorStyle: childNode.colorStyle,
                    sortOrder: index,
                    tab: tab,
                    parent: entity
                )
                context.insert(childEntity)
            }

            removeSubtree(of: childEntity, from: &reusableEntitiesByID)
            childEntity.parent = entity
            childEntity.tab = tab
            childEntity.sortOrder = index
            updateEntityTree(
                existing: childEntity,
                from: childNode,
                tab: tab,
                context: context,
                reusableEntitiesByID: &reusableEntitiesByID
            )
            updatedChildren.append(childEntity)
        }

        entity.children = updatedChildren
    }

    private static func removeSubtree(
        of entity: GradebookNodeEntity,
        from reusableEntitiesByID: inout [UUID: GradebookNodeEntity]
    ) {
        reusableEntitiesByID.removeValue(forKey: entity.id)
        for child in entity.children {
            removeSubtree(of: child, from: &reusableEntitiesByID)
        }
    }
}
