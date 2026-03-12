import Foundation

enum CSVImportService {

    /// Parse student names from CSV-formatted content.
    /// Handles various formats: single column, multi-column with optional number prefix,
    /// and skips header rows containing typical header keywords.
    static func parseStudentNames(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var names: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let columns = trimmed.components(separatedBy: CharacterSet(charactersIn: ",;\t"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }

            // Skip header row
            if index == 0 {
                let headerKeywords = ["name", "vorname", "nachname", "schüler", "schuelername", "firstname", "lastname", "student"]
                let lowerLine = trimmed.lowercased()
                if headerKeywords.contains(where: { lowerLine.contains($0) }) {
                    continue
                }
            }

            // Heuristic: if 2+ columns, try to combine last name + first name
            if columns.count >= 2 {
                let first = columns[0]
                let second = columns[1]

                if !first.isEmpty && !second.isEmpty {
                    if Int(first) != nil {
                        // First column is a number (e.g. running number) -> name starts at column 2
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
