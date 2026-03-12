# Refaktorisierung - Aktueller Stand

## Ziel

Diese Datei dokumentiert den aktuellen, bereinigten Architekturstand der App. Sie ersetzt ältere Notizen, die sich noch auf inzwischen entfernte oder umgestellte Implementierungen bezogen.

## Aktive Struktur

### Dashboard und Navigation

- `ContentView.swift` enthält die Tab-Struktur der App.
- `ÜbersichtView` ist der Dashboard-Einstieg für die Module.
- Die Modulnavigation wird über `TeacherSuiteModule` und `TeacherSuiteModuleDescriptor` in `App/Navigation/TeacherSuiteModules.swift` beschrieben.
- Das Modul `Notenverwaltung` führt auf `GradeBookMainView`.

### Notenverwaltung

Die aktive Notenverwaltung besteht aus diesen Bausteinen:

- `Features/GradeManagement/Views/GradeBookMainView.swift`
  Einstieg in die Notenverwaltung mit Klassenübersicht.

- `Features/GradeManagement/Views/ClassGradebooksDetailView.swift`
  Detailansicht einer Klasse mit Reiterverwaltung.

- `Features/GradeManagement/Views/GradebookDetailView.swift`
  Kern-View der Notentabelle. Das File ist bewusst in mehrere Teil-Dateien aufgeteilt:
  - `GradebookDetailView.swift`
  - `GradebookDetailView+Layout.swift`
  - `GradebookDetailView+Interactions.swift`
  - `GradebookDetailView+Grid.swift`

- `Features/GradeManagement/Models/GradeBookModels.swift`
  Enthält die aktuell verwendeten In-Memory-Modelle für die Notenverwaltung:
  - `WeightOption`
  - `GradeTileNode`
  - `GradebookColumn`
  - `StudentGradeRow`
  - `ClassGradebookState`
  - `GradebookTabState`
  - `ClassGradebooksState`
  - `GradeTileTree`

- `Features/GradeManagement/Migration/GradebookSnapshotStore.swift`
  Persistiert den Tabellen- und Tab-Zustand als SwiftData-Snapshot.

- `Features/GradeManagement/Migration/LegacyGradebookMigration.swift`
  Einmalige Migration aus der alten JSON-Datei in SwiftData.

### Domänenmodelle

Die persistierten Kerndaten liegen getrennt in:

- `Core/Domain/CoreEducationModels.swift`
  - `Teacher`
  - `Subject`
  - `SchoolYear`
  - `Term`
  - `SchoolClass`
  - `Course`
  - `Student`

- `Features/GradeManagement/Models/GradeAssessmentModels.swift`
  - `Assessment`
  - `GradeEntry` (inkl. `rawValue` für Text/Emoji)
  - `GradeComment`
  - Bewertungsbezogene Hilfstypen

## Bereinigungen

Folgende Redundanzen wurden entfernt:

- Die alte parallele Notenoberfläche `GradeBookView.swift` wurde entfernt.
- Das alte Template-Modell `Item.swift` wurde entfernt.
- Der Tab `NotenView` verwendet jetzt dieselbe aktive Notenverwaltung wie die Dashboard-Kachel.
- Veraltete Legacy-Typen für die frühere `GradeBookView`-Implementierung wurden aus `GradeBookModels.swift` entfernt.
- Die JSON-Persistenz für Noten (`GradebookPersistenceService`) wurde entfernt und durch SwiftData ersetzt.

## Aktuelle Verantwortlichkeiten der Dateien

- `ContentView.swift`
  Tab-Struktur, Dashboard, Modulnavigation, einfache Platzhalter-Tabs.

- `App/Persistence/PersistenceController.swift`
  Erstellt und kapselt den SwiftData-Container der App. Enthält aktuell auch einen pragmatischen Store-Reset-Fallback als letzten Notfall.

- `App/Migration/MigrationGateView.swift`
  Führt die Gradebook-Migration beim App-Start aus, bevor die Hauptoberfläche erscheint.

- `Features/GradeManagement/Models/GradeBookModels.swift`
  Unterstützende Zustands- und Strukturmodelle für die aktive Notenverwaltung.

- `Features/GradeManagement/ViewModels/GradebookDetailViewModel.swift`
  UI-orientiertes ViewModel der Notentabelle.

- `Features/GradeManagement/Services/GradebookDetailInteractor.swift`
  Bündelt fachliche Gradebook-Mutationen und entlastet das ViewModel.

- `DesignSystem.swift`
  Zentrale Designkonstanten, Farben und wiederverwendbare UI-Helfer.

- `FeatureViews.swift`
  Wiederverwendbare Placeholder-Views für nicht ausgebaute Bereiche.

## Hinweise für zukünftige Änderungen

1. Neue Funktionen der Notenverwaltung sollten auf dem Stack `GradeBookMainView` / `ClassGradebooksDetailView` / `GradebookDetailView` aufbauen.
2. Neue persistierte Bildungsdaten gehören in `Core/Domain` oder in ein klar abgegrenztes Feature-Modell unter `Features/.../Models`.
3. Zusätzliche UI-Helfer sollten nur dann in `FeatureViews.swift` landen, wenn sie wirklich feature-übergreifende Platzhalter oder Templates sind.
4. Diese Datei sollte nur Aussagen enthalten, die am aktuellen Code verifiziert wurden. Nicht belegbare Metriken oder allgemeine Performance-Behauptungen sollten hier nicht dokumentiert werden.

## Kurzfazit

Der Notenbereich ist jetzt auf einen aktiven Implementierungsweg reduziert und deutlich klarer entlang des Features `GradeManagement` geschnitten. App-Bootstrap, Persistenz, Migration, Views, Modelle und Services sind heute konsistenter getrennt als zuvor.
