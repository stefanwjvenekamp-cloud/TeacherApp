import Foundation
import SwiftData

enum PersistenceController {
    static let sharedModelContainer: ModelContainer = makeModelContainer()
    private static let allowsStoreResetFallback = true

    static let schema = Schema([
        Teacher.self,
        Subject.self,
        SchoolYear.self,
        Term.self,
        Course.self,
        SchoolClass.self,
        GradebookTabEntity.self,
        GradebookNodeEntity.self,
        GradebookRowEntity.self,
        GradebookCellValueEntity.self,
        Student.self,
        Assessment.self,
        GradeEntry.self,
        GradeComment.self,
        GradebookSnapshot.self
    ])

    static func makeModelContainer() -> ModelContainer {
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try makeContainer(with: modelConfiguration)
        } catch let initialError {
            guard allowsStoreResetFallback else {
                fatalError("Could not create ModelContainer without reset fallback: \(initialError)")
            }

            let resetResult = resetStoreFiles(for: modelConfiguration)
            guard resetResult.didRemoveAnyFile else {
                fatalError(
                    """
                    Could not create ModelContainer. Initial error: \(initialError).
                    Store reset fallback did not remove any files.
                    """
                )
            }

            do {
                return try makeContainer(with: modelConfiguration)
            } catch let retryError {
                fatalError(
                    """
                    Could not create ModelContainer after store reset.
                    Initial error: \(initialError)
                    Reset removed files: \(resetResult.removedFiles.joined(separator: ", "))
                    Retry error: \(retryError)
                    """
                )
            }
        }
    }

    private static func makeContainer(with configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [configuration])
    }

    @discardableResult
    private static func resetStoreFiles(for configuration: ModelConfiguration) -> StoreResetResult {
        let storeURL = configuration.url
        let storeDir = storeURL.deletingLastPathComponent()
        let baseName = storeURL.lastPathComponent
        var removedFiles: [String] = []

        for suffix in ["", "-wal", "-shm"] {
            let fileURL = storeDir.appendingPathComponent(baseName + suffix)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            do {
                try FileManager.default.removeItem(at: fileURL)
                removedFiles.append(fileURL.lastPathComponent)
            } catch {
                assertionFailure("Failed to remove store file \(fileURL.lastPathComponent): \(error)")
            }
        }

        return StoreResetResult(removedFiles: removedFiles)
    }
}

private struct StoreResetResult {
    let removedFiles: [String]

    var didRemoveAnyFile: Bool {
        !removedFiles.isEmpty
    }
}
