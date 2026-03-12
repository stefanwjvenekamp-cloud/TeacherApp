# Notenverwaltung (TeacherApp)

## Überblick

Eine modulare iPad-App für Lehrkräfte. Der aktuell ausgebaute Bereich ist die **Notenverwaltung** — eine frei konfigurierbare Notentabelle mit verschachteltem Gewichtungsbaum. Weitere Module (Kalender, Planung, Dokumentation, Gruppeneinteilung, Umfragen) sind als Platzhalter vorbereitet.

## Was aktuell funktioniert

- Dashboard mit Modulkacheln und Navigation
- Klassenübersicht mit Schüleranzahl
- Notentabelle mit frei konfigurierbaren Spalten und verschachteltem Gewichtungsbaum
- Mehrere Tabs pro Klasse (z.B. Schuljahre)
- Schüler hinzufügen, löschen, umbenennen (einzeln oder per CSV-Import)
- Knoten hinzufügen, löschen, verschieben, umbenennen, Gewichte verteilen
- Automatische Durchschnittsberechnung mit gewichtetem Notenbaum
- Zoom und horizontales Scrollen der Tabelle
- Persistenz über SwiftData — alle Daten werden lokal auf dem Gerät gespeichert

## Architektur

### Die drei Schichten

```
┌─────────────────────────────────────┐
│  Views (SwiftUI)                    │  Was der Nutzer sieht
│  GradeBookMainView                  │
│  ClassGradebooksDetailView          │
│  GradebookDetailView + Popups       │
├─────────────────────────────────────┤
│  ViewModel + Services               │  Logik und Zustandsverwaltung
│  GradebookDetailViewModel           │
│  GradebookNodeService               │
│  GradebookStudentService            │
│  GradebookRepository                │
├─────────────────────────────────────┤
│  SwiftData Entities                 │  Was in der Datenbank gespeichert wird
│  SchoolClass, Student               │
│  GradebookTabEntity                 │
│  GradebookNodeEntity                │
│  GradebookRowEntity                 │
│  GradebookCellValueEntity           │
└─────────────────────────────────────┘
```

### Datenmodell

```
SchoolClass (z.B. "10b - Deutsch")
├── students: [Student]
└── gradebookTabs: [GradebookTabEntity]  (z.B. "2025/2026")
                    ├── nodes: [GradebookNodeEntity]  ← der Notenbaum
                    └── rows: [GradebookRowEntity]    ← Schüler-Tab-Verknüpfung
                               └── cellValues: [GradebookCellValueEntity]  ← einzelne Noten
```

### Der Notenbaum

Das Herzstück der App ist ein verschachtelter Gewichtungsbaum. Jeder Knoten ist entweder ein **Berechnungsknoten** (fasst Kinder zusammen) oder ein **Eingabeknoten** (hier wird eine Note eingetragen):

```
Schuljahr (100%)
├── Schulhalbjahr 1 (50%)           ← Berechnung
│   ├── Schriftliche Leistungen (50%)   ← Berechnung
│   │   ├── Klassenarbeit 1 (50%)       ← Eingabe
│   │   └── Klassenarbeit 2 (50%)       ← Eingabe
│   └── Mündliche Leistungen (50%)      ← Berechnung
│       └── Mündliche Mitarbeit (100%)  ← Eingabe
└── Schulhalbjahr 2 (50%)
    └── ...
```

Dieser Baum existiert in zwei Formen:
- **Im Speicher** als `GradeTileNode` (verschachtelter Struct-Baum) — schnell zu bearbeiten
- **In der Datenbank** als `GradebookNodeEntity` (flache Tabelle mit parent/child-Verknüpfungen) — persistent

Der `GradebookTreeService` übersetzt zwischen beiden Formen.

### Datenfluss

**Noteneingabe:**
```
Lehrer tippt "2,3" → GradeInputPopup → ViewModel.setInputValue()
  → aktualisiert lokalen Zustand (rows)
  → GradebookRepository.upsertCellValue() → Datenbank
```

**App-Start:**
```
NotenverwaltungApp → ModelContainer (Datenbank öffnen)
  → MigrationGateView → alte Formate migrieren
  → GradeBookMainView → Klassen laden, Default-Tabs sicherstellen
  → Nutzer wählt Klasse → ClassGradebooksDetailView
  → Nutzer sieht Tab → GradebookDetailView
    → ViewModel liest Notenbaum + Schülerzeilen aus Datenbank
```

## Projektstruktur

### App-Einstieg
| Datei | Beschreibung |
|-------|-------------|
| `NotenverwaltungApp.swift` | App-Entry-Point, ModelContainer, MigrationGate |
| `ContentView.swift` | TabBar (Übersicht, Noten, Briefe, Kalender, Planung) + Dashboard |

### Datenmodelle
| Datei | Beschreibung |
|-------|-------------|
| `Core/Domain/CoreEducationModels.swift` | Stammdaten: SchoolClass, Student, Teacher, Subject, Course |
| `Features/.../Models/GradebookEntities.swift` | Notentabellen-Entities: Tab, Node, Row, CellValue |
| `Features/.../Models/GradeAssessmentModels.swift` | Assessment, GradeEntry, GradeComment |
| `GradeBookModels.swift` | In-Memory-Modelle: GradeTileNode, GradeTileTree, Enums |
| `Features/.../Models/GradebookViewHelpers.swift` | UI-Hilfstypen: InsertionSlot, GradeInputCellTarget etc. |

### ViewModel
| Datei | Beschreibung |
|-------|-------------|
| `Features/.../ViewModels/GradebookDetailViewModel.swift` | Zentrales ViewModel für die Notentabelle — hält UI-State und delegiert an Services |

### Views
| Datei | Beschreibung |
|-------|-------------|
| `ClassSelectionView.swift` | GradeBookMainView, ClassGradebooksDetailView, GradebookDetailView |
| `Features/.../Views/HeaderTileView.swift` | Einzelne Kachel im Tabellenkopf |
| `Features/.../Views/FloatingTileSettingsPanel.swift` | Bearbeitungs-Popup für Knoten |
| `Features/.../Views/GradeInputPopup.swift` | Noteneingabe-Popup |
| `Features/.../Views/AddStudentsPopup.swift` | Schüler hinzufügen (einzeln + CSV) |
| `Features/.../Views/ClassCard.swift` | Klassenkarte in der Übersicht |
| `Features/.../Views/GradebookTableComponents.swift` | Scroll-Synchronisierung |

### Services
| Datei | Beschreibung |
|-------|-------------|
| `Shared/Services/GradebookRepository.swift` | Hauptzugang zur Datenbank — CRUD für Tabs, Rows, Nodes, CellValues |
| `Shared/Services/GradebookTreeService.swift` | Übersetzung zwischen GradeTileNode (Speicher) und NodeEntity (DB) |
| `Shared/Services/GradebookNodeService.swift` | Baumoperationen: Knoten hinzufügen, löschen, verschieben, Gewichte |
| `Shared/Services/GradebookStudentService.swift` | Schülerverwaltung: hinzufügen, löschen, umbenennen |
| `Shared/Services/CSVImportService.swift` | CSV-Parsing für Schüler-Import |
| `Shared/Services/MockSeedDataService.swift` | Demo-Daten beim ersten Start |
| `Shared/Services/GradebookMigrationService.swift` | Migriert alte Snapshot-Daten in Entities |
| `Shared/Services/LegacyGradebookMigration.swift` | Migriert uraltes JSON-Format |
| `Shared/Services/GradebookSnapshotStore.swift` | Liest alte Snapshot-Daten (nur noch für Migration) |

### Sonstiges
| Datei | Beschreibung |
|-------|-------------|
| `DesignSystem.swift` | Farben, Abstände, Schriftgrößen, plattformübergreifende Helfer |
| `FeatureViews.swift` | Platzhalter-Views für zukünftige Module |
| `App/Navigation/TeacherSuiteModules.swift` | Modul-Definitionen für das Dashboard |

## Migration

Beim App-Start werden zwei Migrationspfade geprüft:

1. **Legacy-JSON** (`gradebook_data.json`): Uraltes Format aus der ersten App-Version. Wird in SwiftData-Entities konvertiert und die Datei gelöscht.
2. **Snapshot-Migration** (`GradebookSnapshot`): Älteres SwiftData-Format, bei dem der Tabellenzustand als JSON-Blob gespeichert wurde. Wird in einzelne Entities (Tab, Node, Row, CellValue) aufgelöst.

Falls die Datenbank inkompatibel ist (z.B. nach größeren Schema-Änderungen), wird sie automatisch gelöscht und neu erstellt.
