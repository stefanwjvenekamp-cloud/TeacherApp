import SwiftData

enum GradebookMigrationService {
    @discardableResult
    @MainActor
    static func migrateIfNeeded(context: ModelContext) -> Bool {
        let didLegacyMigration = LegacyGradebookMigration.migrateIfNeeded(in: context)
        let didSnapshotMigration = migrateSnapshotsIfNeeded(in: context)
        return didLegacyMigration || didSnapshotMigration
    }

    @MainActor
    private static func migrateSnapshotsIfNeeded(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<GradebookSnapshot>()
        let snapshots = (try? context.fetch(descriptor)) ?? []
        guard !snapshots.isEmpty else { return false }

        let classesDescriptor = FetchDescriptor<SchoolClass>()
        let classes = (try? context.fetch(classesDescriptor)) ?? []
        let classesByID = Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0) })
        var migratedAny = false

        for snapshot in snapshots {
            guard let schoolClass = classesByID[snapshot.classId],
                  let state = GradebookSnapshotStore.decodeState(from: snapshot.data)
            else { continue }

            GradebookRepository.bootstrapTabsIfNeeded(for: schoolClass, state: state, in: context)

            let tabsByID = Dictionary(uniqueKeysWithValues: GradebookRepository.tabs(for: schoolClass).map { ($0.id, $0) })
            for tabState in state.tabs {
                guard let tab = tabsByID[tabState.id] else { continue }
                GradebookRepository.bootstrapNodesIfNeeded(for: tab, root: tabState.gradebook.root, in: context)
                GradebookRepository.bootstrapRowsIfNeeded(for: tab, state: tabState.gradebook, schoolClass: schoolClass, in: context)
                GradebookRepository.bootstrapCellValuesIfNeeded(for: tab, state: tabState.gradebook, in: context)
                migratedAny = true
            }

            context.delete(snapshot)
        }

        if migratedAny {
            try? context.save()
        }

        return migratedAny
    }
}
