import Foundation
import SwiftData

@Model
final class GradebookTabEntity {
    var id: UUID
    var title: String
    var sortOrder: Int
    var roundingDecimals: Int

    var schoolClass: SchoolClass?
    @Relationship(deleteRule: .cascade, inverse: \GradebookNodeEntity.tab)
    var nodes: [GradebookNodeEntity]
    @Relationship(deleteRule: .cascade, inverse: \GradebookRowEntity.tab)
    var rows: [GradebookRowEntity]

    init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int,
        roundingDecimals: Int = 2,
        schoolClass: SchoolClass? = nil
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.roundingDecimals = roundingDecimals
        self.schoolClass = schoolClass
        self.nodes = []
        self.rows = []
    }
}

@Model
final class GradebookNodeEntity {
    var id: UUID
    var title: String
    var nodeTypeRawValue: String
    var weightPercent: Double
    var isWeightManuallySet: Bool
    var showsAsColumn: Bool
    var colorStyleRawValue: String
    var sortOrder: Int

    var tab: GradebookTabEntity?
    var parent: GradebookNodeEntity?

    @Relationship(deleteRule: .cascade, inverse: \GradebookNodeEntity.parent)
    var children: [GradebookNodeEntity]
    @Relationship(inverse: \GradebookCellValueEntity.node)
    var cellValues: [GradebookCellValueEntity]

    init(
        id: UUID = UUID(),
        title: String,
        nodeType: GradeTileType,
        weightPercent: Double,
        isWeightManuallySet: Bool = false,
        showsAsColumn: Bool = true,
        colorStyle: GradeTileColorStyle = .automatic,
        sortOrder: Int,
        tab: GradebookTabEntity? = nil,
        parent: GradebookNodeEntity? = nil
    ) {
        self.id = id
        self.title = title
        self.nodeTypeRawValue = nodeType.rawValue
        self.weightPercent = weightPercent
        self.isWeightManuallySet = isWeightManuallySet
        self.showsAsColumn = showsAsColumn
        self.colorStyleRawValue = colorStyle.rawValue
        self.sortOrder = sortOrder
        self.tab = tab
        self.parent = parent
        self.children = []
        self.cellValues = []
    }

    var nodeType: GradeTileType {
        get { GradeTileType(rawValue: nodeTypeRawValue) ?? .calculation }
        set { nodeTypeRawValue = newValue.rawValue }
    }

    var colorStyle: GradeTileColorStyle {
        get { GradeTileColorStyle(rawValue: colorStyleRawValue) ?? .automatic }
        set { colorStyleRawValue = newValue.rawValue }
    }
}

@Model
final class GradebookRowEntity {
    var id: UUID
    var sortOrder: Int

    var tab: GradebookTabEntity?
    var student: Student?
    @Relationship(deleteRule: .cascade, inverse: \GradebookCellValueEntity.row)
    var cellValues: [GradebookCellValueEntity]

    init(
        id: UUID = UUID(),
        sortOrder: Int,
        tab: GradebookTabEntity? = nil,
        student: Student? = nil
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.tab = tab
        self.student = student
        self.cellValues = []
    }
}

@Model
final class GradebookCellValueEntity {
    var id: UUID
    var rawValue: String

    var row: GradebookRowEntity?
    var node: GradebookNodeEntity?

    init(
        id: UUID = UUID(),
        rawValue: String = "",
        row: GradebookRowEntity? = nil,
        node: GradebookNodeEntity? = nil
    ) {
        self.id = id
        self.rawValue = rawValue
        self.row = row
        self.node = node
    }
}
