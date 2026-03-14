# Notenverwaltung

Eine modulare Lehrer-App in SwiftUI und SwiftData. Der aktuell am weitesten ausgebaute Bereich ist die Notenverwaltung mit klassenbezogenen Notentabellen, verschachteltem Gewichtungsbaum und einem mehrstufigen CSV-Import für Schülerdaten.

## Projektziel

Die App soll Lehrkräften eine zentrale Arbeitsoberfläche für mehrere schulische Aufgaben bieten. Die langfristige Idee ist eine modulare Teacher-Suite, in der dieselbe Schüleridentität in mehreren Bereichen wiederverwendet werden kann, statt pro Modul neu dupliziert zu werden.

Aktuell liegt der Schwerpunkt auf:

- Notenverwaltung
- Klassenkontext und Schülerzuordnungen
- sauberer CSV-Import mit Review vor dem Speichern
- lokaler Persistenz über SwiftData

Weitere Module wie Kalender, Planung, Dokumentation, Gruppeneinteilung und Umfragen sind bereits als Einstiegspunkte bzw. Platzhalter vorhanden.

## Aktueller IST-Stand

### Bereits umgesetzt

- modulare App-Struktur mit Dashboard und Modulnavigation
- SwiftData-basierte Persistenz
- zentrale Schüleridentität über `Student`
- Trennung zwischen Person und Klassenzugehörigkeit über `ClassEnrollment`
- klassenbezogene Notentabellen über `GradebookTabEntity`, `GradebookRowEntity` und `GradebookCellValueEntity`
- gewichteter, verschachtelter Notenbaum mit frei bearbeitbaren Knoten
- mehrere Tabs pro Klasse
- Schüler hinzufügen, löschen und umbenennen
- CSV-Import mit Review-Schritt vor dem Commit
- Matching vorhandener Schüler mit mehreren Match-Stufen
- Unit-Tests für Gradebook-Logik, Enrollment-Integrität und Import-Pipeline

### CSV-Import aktuell

Der Import läuft inzwischen fachlich in klar getrennten Schritten:

```text
CSV
→ CSVImportCandidate
→ CSVImportMatchResult
→ CSVImportResolution
→ Commit
```

Bereits vorhanden:

- Header-Mapping für Vorname/Nachname
- Validierung pro Zeile
- Matching gegen vorhandene `Student`-Objekte
- Match-Typen:
  - `exact`
  - `normalized`
  - `legacySegmented`
  - `germanNormalized`
- Review-UI für die fachliche Entscheidung pro Zeile
- Commit-Schicht für vollständig aufgelöste Resolutionen

Wichtig:

- Namen sind nie Identität.
- CSV-Import merged nicht blind.
- Die endgültige Identitätsentscheidung liegt beim Nutzer.

## Fachliche Kernarchitektur

Die zentrale Struktur der App ist aktuell:

```text
Student
   │
ClassEnrollment
   │
SchoolClass
   │
GradebookRowEntity
   │
GradeEntry
```

### Bedeutung der Entitäten

- `Student`
  Zentrale fachliche Personentität mit stabiler UUID.

- `ClassEnrollment`
  Zugehörigkeit eines Students zu genau einer Klasse. Hier liegen kontextabhängige Informationen wie z. B. `studentNumber`.

- `SchoolClass`
  Organisatorischer Klassenkontext.

- `GradebookRowEntity`
  Tabellenzeile innerhalb eines Gradebook-Tabs. Sie gehört fachlich zu einem Enrollment, nicht direkt zur Person.

- `GradeEntry`
  Noten-/Bewertungsbezug mit Row-Kontext.

Diese Trennung ist die Grundlage dafür, dass dieselbe Person später in mehreren Modulen und mehreren Klassen/Kursen sauber referenzierbar bleibt.

## Technischer Aufbau

### UI / App

- `NotenverwaltungApp.swift`
- `ContentView.swift`
- `App/Navigation/TeacherSuiteModules.swift`

### Persistenz / Bootstrap

- `App/Persistence/PersistenceController.swift`
- `App/Migration/MigrationGateView.swift`

### Domäne

- `Core/Domain/CoreEducationModels.swift`
- `Features/GradeManagement/Models/GradeAssessmentModels.swift`
- `Features/GradeManagement/Models/GradebookEntities.swift`
- `Features/GradeManagement/Models/GradeBookModels.swift`

### Gradebook-Logik

- `Features/GradeManagement/ViewModels/GradebookDetailViewModel.swift`
- `Features/GradeManagement/Services/GradebookDetailInteractor.swift`
- `Features/GradeManagement/Services/GradebookRepository.swift`
- `Features/GradeManagement/Services/GradebookNodeService.swift`
- `Features/GradeManagement/Services/GradebookStudentService.swift`
- `Features/GradeManagement/Services/GradebookTreeService.swift`

### Import

- `Features/GradeManagement/Services/CSVImportService.swift`
- `Features/GradeManagement/Views/AddStudentsPopup.swift`

### Tests

- `NotenverwaltungTests/GradebookLogicTests.swift`

## Was professionell bereits gut gelöst ist

- saubere Trennung von Schüleridentität und Klassenkontext
- explizite Review-Logik im CSV-Import statt stiller Auto-Merges
- Wiederverwendung von Enrollments statt doppelter Kontextobjekte
- mehrstufige Matching-Engine mit transparenten Match-Qualitäten
- konsequente Tests für Logikpfade statt nur UI-Verhalten

## Was als Nächstes noch passieren sollte

### Kurzfristig

- Import-Review-UX weiter verfeinern
- bessere Rückmeldungen für Konflikte und mehrdeutige Matches
- CSV-Import robuster gegen reale Schuldateien machen
- technische Altpfade und Migrationsreste weiter aufräumen

### Mittelfristig

- Kurs-/Gruppenlogik fachlich auf dieselbe Identitätsarchitektur heben
- weitere Module an die zentrale Schüleridentität anbinden
- Tests stärker auf mehrere Dateien und Fachbereiche aufteilen
- Persistenzstrategie produktionsnäher machen, insbesondere beim Store-Reset-Fallback

### Langfristig

- modulübergreifende Schülerakte
- gemeinsame Stammdaten für Klassen, Kurse, Leistungsnachweise und Dokumentation
- produktionsreife Import- und Konfliktbearbeitung
- stabilere Versionierung/Migration des Datenmodells

## Offene Punkte / bewusste Grenzen des aktuellen Standes

- einige ältere Migrations- und Übergangspfade existieren noch
- der Store-Reset-Fallback ist für Entwicklung hilfreich, aber noch nicht produktionsreif
- der Fokus liegt aktuell klar auf der Notenverwaltung; andere Module sind noch nicht fachlich ausgebaut
- der CSV-Import ist funktional stark verbessert, aber noch kein vollständiger Import-Assistent für alle Schulrealitäten

## Entwicklung und Tests

Die App basiert auf:

- SwiftUI
- SwiftData
- Testing / XCTest-nahe Teststruktur im Projekt

Die Logiktests liegen aktuell gebündelt in:

- `NotenverwaltungTests/GradebookLogicTests.swift`

Zuletzt ist die Suite auf dem aktuellen Stand grün gelaufen.

## Kurzfazit

Die App ist nicht mehr nur ein UI-Prototyp, sondern entwickelt sich zu einer fachlich sauberen Lehrer-Engine mit klarer Identitäts- und Importarchitektur. Der Schwerpunkt liegt derzeit auf einer belastbaren Notenverwaltung als Kernmodul. Der nächste große Schritt ist, dieselbe Qualität schrittweise auf weitere Module und die restliche Datenmodellierung zu übertragen.
