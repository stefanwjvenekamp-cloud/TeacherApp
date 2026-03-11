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

- `ClassSelectionView.swift`
  Enthält die Hauptoberfläche der Notenverwaltung:
  - `GradeBookMainView`
  - Klassenübersicht
  - Detailansicht pro Klasse
  - Tabellenansicht mit Zoom und Bearbeitungslogik

- `GradeBookModels.swift`
  Enthält die aktuell verwendeten In-Memory-Modelle für die Notenverwaltung:
  - `WeightOption`
  - `GradeTileNode`
  - `GradebookColumn`
  - `StudentGradeRow`
  - `ClassGradebookState`
  - `GradebookTabState`
  - `ClassGradebooksState`
  - `GradeTileTree`

- `Shared/Services/GradebookPersistenceService.swift`
  Kapselt das Speichern und Laden des aktiven Gradebook-Zustands.

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
  - `GradeEntry`
  - `GradeComment`
  - Bewertungsbezogene Hilfstypen

## Bereinigungen

Folgende Redundanzen wurden entfernt:

- Die alte parallele Notenoberfläche `GradeBookView.swift` wurde entfernt.
- Das alte Template-Modell `Item.swift` wurde entfernt.
- Der Tab `NotenView` verwendet jetzt dieselbe aktive Notenverwaltung wie die Dashboard-Kachel.
- Veraltete Legacy-Typen für die frühere `GradeBookView`-Implementierung wurden aus `GradeBookModels.swift` entfernt.

## Aktuelle Verantwortlichkeiten der Dateien

- `ContentView.swift`
  Tab-Struktur, Dashboard, Modulnavigation, einfache Platzhalter-Tabs.

- `ClassSelectionView.swift`
  Fachliche Hauptlogik und UI der aktiven Notenverwaltung.

- `GradeBookModels.swift`
  Unterstützende Zustands- und Strukturmodelle für die aktive Notenverwaltung.

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

Der Notenbereich ist jetzt auf einen aktiven Implementierungsweg reduziert. Navigation, UI und zugehörige Hilfsmodelle sind klarer geschnitten als zuvor, und die zuvor vorhandene Doppelstruktur für die Notenverwaltung ist entfernt.
