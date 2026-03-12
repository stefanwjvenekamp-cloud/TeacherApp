//
//  GradeBookModels.swift
//  Notenverwaltung
//
//  Datenmodell für die Notenverwaltung
//

import Foundation

// MARK: - Weight Selection Options

struct WeightOption: Identifiable {
    let id: Double
    let value: Double
    let label: String
    
    init(value: Double) {
        self.id = value
        self.value = value
        self.label = "\(Int(value))%"
    }
}

extension WeightOption {
    static let availableWeights: [WeightOption] = [
        0, 10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 100
    ].map { WeightOption(value: Double($0)) }
}

// MARK: - In-Memory Gradebook Hierarchy (V2)

enum GradeTileType: String, Codable, CaseIterable {
    case calculation
    case input
}

enum GradeTileColorStyle: String, Codable, CaseIterable {
    case automatic
    case slate
    case blue
    case green
    case orange
    case red
}

struct GradeTileNode: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var type: GradeTileType
    var weightPercent: Double
    var isWeightManuallySet: Bool
    var showsAsColumn: Bool
    var colorStyle: GradeTileColorStyle
    var children: [GradeTileNode]

    init(
        id: UUID = UUID(),
        title: String,
        type: GradeTileType,
        weightPercent: Double = 100,
        isWeightManuallySet: Bool = false,
        showsAsColumn: Bool? = nil,
        colorStyle: GradeTileColorStyle = .automatic,
        children: [GradeTileNode] = []
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.weightPercent = weightPercent
        self.isWeightManuallySet = isWeightManuallySet
        self.showsAsColumn = showsAsColumn ?? true
        self.colorStyle = colorStyle
        self.children = children
    }

    var isLeaf: Bool {
        children.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case weightPercent
        case isWeightManuallySet
        case showsAsColumn
        case colorStyle
        case children
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(GradeTileType.self, forKey: .type)
        weightPercent = try container.decode(Double.self, forKey: .weightPercent)
        isWeightManuallySet = try container.decodeIfPresent(Bool.self, forKey: .isWeightManuallySet) ?? false
        showsAsColumn = try container.decode(Bool.self, forKey: .showsAsColumn)
        colorStyle = try container.decode(GradeTileColorStyle.self, forKey: .colorStyle)
        children = try container.decode([GradeTileNode].self, forKey: .children)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(weightPercent, forKey: .weightPercent)
        try container.encode(isWeightManuallySet, forKey: .isWeightManuallySet)
        try container.encode(showsAsColumn, forKey: .showsAsColumn)
        try container.encode(colorStyle, forKey: .colorStyle)
        try container.encode(children, forKey: .children)
    }
}

struct GradebookColumn: Identifiable, Hashable {
    let id: UUID
    let nodeID: UUID
    let title: String
    let type: GradeTileType
    let pathTitles: [String]
}

struct StudentGradeRow: Identifiable, Hashable, Codable {
    let id: UUID
    var studentName: String
    var inputValues: [UUID: String]

    init(id: UUID = UUID(), studentName: String, inputValues: [UUID: String] = [:]) {
        self.id = id
        self.studentName = studentName
        self.inputValues = inputValues
    }
}

struct ClassGradebookState: Hashable, Codable {
    var root: GradeTileNode
    var rows: [StudentGradeRow]
    var roundingDecimals: Int

    init(root: GradeTileNode, rows: [StudentGradeRow], roundingDecimals: Int = 2) {
        self.root = root
        self.rows = rows
        self.roundingDecimals = roundingDecimals
    }
}

struct GradebookTabState: Identifiable, Hashable, Codable {
    var id: UUID
    var schoolYear: String
    var gradebook: ClassGradebookState

    init(id: UUID = UUID(), schoolYear: String, gradebook: ClassGradebookState) {
        self.id = id
        self.schoolYear = schoolYear
        self.gradebook = gradebook
    }
}

struct ClassGradebooksState: Hashable, Codable {
    var tabs: [GradebookTabState]
    var selectedTabID: UUID?

    init(tabs: [GradebookTabState], selectedTabID: UUID? = nil) {
        self.tabs = tabs
        self.selectedTabID = selectedTabID ?? tabs.first?.id
    }
}

enum GradeTileTree {
    static func standardRoot() -> GradeTileNode {
        GradeTileNode(
            title: "Schuljahr",
            type: .calculation,
            weightPercent: 100,
            showsAsColumn: true,
            children: [
                GradeTileNode(
                    title: "Schulhalbjahr 1",
                    type: .calculation,
                    weightPercent: 50,
                    showsAsColumn: true,
                    children: [
                        GradeTileNode(
                            title: "Schriftliche Leistungen",
                            type: .calculation,
                            weightPercent: 50,
                            showsAsColumn: true,
                            children: [
                                GradeTileNode(title: "Klassenarbeit 1", type: .input, weightPercent: 50),
                                GradeTileNode(title: "Klassenarbeit 2", type: .input, weightPercent: 50)
                            ]
                        ),
                        GradeTileNode(
                            title: "Mündliche Leistungen",
                            type: .calculation,
                            weightPercent: 50,
                            showsAsColumn: true,
                            children: [
                                GradeTileNode(title: "Mündliche Mitarbeit", type: .input, weightPercent: 100)
                            ]
                        )
                    ]
                ),
                GradeTileNode(
                    title: "Schulhalbjahr 2",
                    type: .calculation,
                    weightPercent: 50,
                    showsAsColumn: true,
                    children: [
                        GradeTileNode(
                            title: "Schriftliche Leistungen",
                            type: .calculation,
                            weightPercent: 50,
                            showsAsColumn: true,
                            children: [
                                GradeTileNode(title: "Klassenarbeit 1", type: .input, weightPercent: 50),
                                GradeTileNode(title: "Klassenarbeit 2", type: .input, weightPercent: 50)
                            ]
                        ),
                        GradeTileNode(
                            title: "Mündliche Leistungen",
                            type: .calculation,
                            weightPercent: 50,
                            showsAsColumn: true,
                            children: [
                                GradeTileNode(title: "Mündliche Mitarbeit", type: .input, weightPercent: 100)
                            ]
                        )
                    ]
                )
            ]
        )
    }

    static func emptyRoot() -> GradeTileNode {
        GradeTileNode(
            title: "Schuljahr",
            type: .calculation,
            weightPercent: 100,
            showsAsColumn: true,
            children: []
        )
    }

    static func columns(from root: GradeTileNode) -> [GradebookColumn] {
        var result: [GradebookColumn] = []
        collectColumns(node: root, path: [], result: &result)
        return result
    }

    static func calculateValue(
        for node: GradeTileNode,
        row: StudentGradeRow,
        roundingDecimals: Int
    ) -> Double? {
        switch node.type {
        case .input:
            guard let raw = row.inputValues[node.id], !raw.isEmpty else { return nil }
            guard let value = Double(raw.replacingOccurrences(of: ",", with: ".")) else { return nil }
            guard value >= 1, value <= 6 else { return nil }
            return round(value, decimals: roundingDecimals)
        case .calculation:
            guard !node.children.isEmpty else { return nil }
            
            // Sammle alle Kinder mit gültigen Werten
            var weightedSum: Double = 0
            var totalUsedWeight: Double = 0
            
            for child in node.children {
                if let childValue = calculateValue(for: child, row: row, roundingDecimals: roundingDecimals) {
                    weightedSum += childValue * child.weightPercent
                    totalUsedWeight += child.weightPercent
                }
            }
            
            // Mindestens ein Kind muss einen Wert haben
            guard totalUsedWeight > 0 else { return nil }
            
            // Gewichteter Durchschnitt (normalisiert auf vorhandene Gewichte)
            let result = weightedSum / totalUsedWeight
            return round(result, decimals: roundingDecimals)
        }
    }

    static func isWeightValid(for parent: GradeTileNode) -> Bool {
        guard parent.type == .calculation, !parent.children.isEmpty else { return true }
        return abs(parent.children.reduce(0.0, { $0 + $1.weightPercent }) - 100.0) < 0.01
    }

    static func isDescendant(root: GradeTileNode, ancestorID: UUID, possibleDescendantID: UUID) -> Bool {
        guard let ancestor = findNode(in: root, id: ancestorID) else { return false }
        return contains(node: ancestor, id: possibleDescendantID)
    }

    static func findNode(in node: GradeTileNode, id: UUID) -> GradeTileNode? {
        if node.id == id { return node }
        for child in node.children {
            if let found = findNode(in: child, id: id) {
                return found
            }
        }
        return nil
    }

    static func updateNode(root: inout GradeTileNode, id: UUID, update: (inout GradeTileNode) -> Void) {
        if root.id == id {
            update(&root)
            return
        }
        for index in root.children.indices {
            updateNode(root: &root.children[index], id: id, update: update)
        }
    }

    static func removeNode(root: inout GradeTileNode, id: UUID) -> GradeTileNode? {
        if let index = root.children.firstIndex(where: { $0.id == id }) {
            return root.children.remove(at: index)
        }
        for index in root.children.indices {
            if let removed = removeNode(root: &root.children[index], id: id) {
                return removed
            }
        }
        return nil
    }

    static func findParentID(root: GradeTileNode, childID: UUID) -> UUID? {
        for child in root.children {
            if child.id == childID { return root.id }
            if let found = findParentID(root: child, childID: childID) {
                return found
            }
        }
        return nil
    }

    static func insertAsChild(root: inout GradeTileNode, parentID: UUID, node: GradeTileNode) {
        updateNode(root: &root, id: parentID) { parent in
            parent.children.append(node)
        }
    }

    static func insertAtSameLevel(
        root: inout GradeTileNode,
        siblingID: UUID,
        node: GradeTileNode,
        after: Bool
    ) {
        insertNearSibling(root: &root, siblingID: siblingID, node: node, after: after)
    }

    private static func collectColumns(node: GradeTileNode, path: [GradeTileNode], result: inout [GradebookColumn]) {
        let currentPath = path + [node]
        let visiblePath = currentPath.map(\.title)

        if node.showsAsColumn {
            result.append(
                GradebookColumn(
                    id: node.id,
                    nodeID: node.id,
                    title: node.title,
                    type: node.type,
                    pathTitles: Array(visiblePath)
                )
            )
        }

        for child in node.children {
            collectColumns(node: child, path: currentPath, result: &result)
        }
    }

    private static func round(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (value * factor).rounded() / factor
    }

    private static func contains(node: GradeTileNode, id: UUID) -> Bool {
        if node.id == id { return true }
        return node.children.contains(where: { contains(node: $0, id: id) })
    }

    @discardableResult
    private static func insertNearSibling(
        root: inout GradeTileNode,
        siblingID: UUID,
        node: GradeTileNode,
        after: Bool
    ) -> Bool {
        if let index = root.children.firstIndex(where: { $0.id == siblingID }) {
            let target = after ? index + 1 : index
            root.children.insert(node, at: target)
            return true
        }
        for index in root.children.indices {
            if insertNearSibling(root: &root.children[index], siblingID: siblingID, node: node, after: after) {
                return true
            }
        }
        return false
    }
}
