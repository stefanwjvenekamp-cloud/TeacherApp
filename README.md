# Notenverwaltung (TeacherApp)

## Überblick
Diese App ist eine modulare Lehrer-Suite. Der aktuell ausgebaute Bereich ist die Notenverwaltung. Weitere Module (Kalender, Planung, Dokumentation, Gruppeneinteilung, Umfragen) sind als Platzhalter vorbereitet.

## Was aktuell funktioniert
- Dashboard mit Modulkacheln und Navigation.
- Notenverwaltung mit Klassenübersicht, Detailansicht und Notentabelle.
- Tabellenstruktur mit Reitern (z. B. Schuljahre) und frei konfigurierbaren Spalten.
- Datenhaltung über SwiftData für Klassen, Schüler und Noten.

## Datenmodell (vereinfacht)
- `SchoolClass` und `Student` sind die Stammdaten.
- `GradeEntry` speichert Einträge pro Schüler und Spalte.
  - `rawValue` enthält auch Text/Emojis.
  - `value` enthält numerische Noten (1–6), wenn möglich.
- Tabellen- und Tab-Struktur wird als Snapshot (`GradebookSnapshot`) gespeichert.

## Migration
Beim ersten Start wird geprüft, ob eine alte JSON-Datei existiert (`gradebook_data.json`).
- Falls ja, werden Klassen, Schüler, Noten und Tabellenstruktur in SwiftData übernommen.
- Danach wird die alte Datei gelöscht.

## Projektstruktur (Kurzfassung)
- `Notenverwaltung/Notenverwaltung/ContentView.swift`
  Tab-Layout + Dashboard.
- `Notenverwaltung/Notenverwaltung/ClassSelectionView.swift`
  Haupt-UI der Notenverwaltung.
- `Notenverwaltung/Notenverwaltung/GradeBookModels.swift`
  In-Memory-Modelle für Tabellenstruktur und UI.
- `Notenverwaltung/Notenverwaltung/Core/Domain/CoreEducationModels.swift`
  SwiftData-Stammdaten.
- `Notenverwaltung/Notenverwaltung/Features/GradeManagement/Models/GradeAssessmentModels.swift`
  SwiftData-Notenmodelle.
- `Notenverwaltung/Notenverwaltung/Shared/Services/GradebookSnapshotStore.swift`
  Speicherung des Tabellenzustands.
- `Notenverwaltung/Notenverwaltung/Shared/Services/LegacyGradebookMigration.swift`
  Migration der Alt-Daten.

## Nächste Schritte (technisch sinnvoll)
- UI-Aktionen für Löschen von Schülern/Noten ergänzen.
- Weitere Module an die gemeinsamen Daten anbinden (Kalender, Planung, Dokumentation).
- Tests für Migration und Datenhaltung ergänzen.
