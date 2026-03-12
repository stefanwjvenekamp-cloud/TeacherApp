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
│  ViewModel + Interactor + Services  │  Logik und Zustandsverwaltung
│  GradebookDetailViewModel           │
│  GradebookDetailInteractor          │
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
  → GradebookDetailInteractor.setInputValue()
  → GradebookRepository.upsertCellValue() → Datenbank
```

**App-Start:**
```
NotenverwaltungApp → PersistenceController (ModelContainer öffnen)
  → MigrationGateView → alte Formate migrieren
  → GradeBookMainView → Klassen laden, Default-Tabs sicherstellen
  → Nutzer wählt Klasse → ClassGradebooksDetailView
  → Nutzer sieht Tab → GradebookDetailView
    → ViewModel delegiert fachliche Lese-/Schreiboperationen an den Interactor
```

## Projektstruktur

### App-Einstieg
| Datei | Beschreibung |
|-------|-------------|
| `NotenverwaltungApp.swift` | App-Entry-Point, Composition Root |
| `App/Persistence/PersistenceController.swift` | Kapselt Schema, ModelContainer und Store-Reset-Fallback |
| `App/Migration/MigrationGateView.swift` | Führt Migrationen vor dem Anzeigen der Hauptoberfläche aus |
| `ContentView.swift` | TabBar (Übersicht, Noten, Briefe, Kalender, Planung) + Dashboard |

### Datenmodelle
| Datei | Beschreibung |
|-------|-------------|
| `Core/Domain/CoreEducationModels.swift` | Stammdaten: SchoolClass, Student, Teacher, Subject, Course |
| `Features/.../Models/GradebookEntities.swift` | Notentabellen-Entities: Tab, Node, Row, CellValue |
| `Features/.../Models/GradeAssessmentModels.swift` | Assessment, GradeEntry, GradeComment |
| `Features/.../Models/GradeBookModels.swift` | In-Memory-Modelle: GradeTileNode, GradeTileTree, Enums |
| `Features/.../Models/GradebookViewHelpers.swift` | UI-Hilfstypen: InsertionSlot, GradeInputCellTarget etc. |

### ViewModel
| Datei | Beschreibung |
|-------|-------------|
| `Features/.../ViewModels/GradebookDetailViewModel.swift` | Zentrales ViewModel für die Notentabelle — hält UI-State und delegiert fachliche Operationen |

### Interactor
| Datei | Beschreibung |
|-------|-------------|
| `Features/.../Services/GradebookDetailInteractor.swift` | Bündelt fachliche Gradebook-Mutationen und Zugriffe auf Repository/Services |

### Views
| Datei | Beschreibung |
|-------|-------------|
| `Features/.../Views/GradeBookMainView.swift` | Einstieg in die Notenverwaltung mit Klassenübersicht |
| `Features/.../Views/ClassGradebooksDetailView.swift` | Detailansicht einer Klasse mit Reiterverwaltung |
| `Features/.../Views/GradebookDetailView.swift` | Kern-View der Notentabelle |
| `Features/.../Views/GradebookDetailView+Layout.swift` | Zoom, Scroll und Tabellenlayout |
| `Features/.../Views/GradebookDetailView+Interactions.swift` | Dialoge, Overlays und Interaktionsflüsse |
| `Features/.../Views/GradebookDetailView+Grid.swift` | Grid-, Zell- und Darstellungslogik |
| `Features/.../Views/HeaderTileView.swift` | Einzelne Kachel im Tabellenkopf |
| `Features/.../Views/FloatingTileSettingsPanel.swift` | Bearbeitungs-Popup für Knoten |
| `Features/.../Views/GradeInputPopup.swift` | Noteneingabe-Popup |
| `Features/.../Views/AddStudentsPopup.swift` | Schüler hinzufügen (einzeln + CSV) |
| `Features/.../Views/ClassCard.swift` | Klassenkarte in der Übersicht |
| `Features/.../Views/GradebookTableComponents.swift` | Scroll-Synchronisierung |

### Services
| Datei | Beschreibung |
|-------|-------------|
| `Features/.../Services/GradebookRepository.swift` | Hauptzugang zur Datenbank — CRUD für Tabs, Rows, Nodes, CellValues |
| `Features/.../Services/GradebookTreeService.swift` | Übersetzung zwischen GradeTileNode (Speicher) und NodeEntity (DB) |
| `Features/.../Services/GradebookNodeService.swift` | Baumoperationen: Knoten hinzufügen, löschen, verschieben, Gewichte |
| `Features/.../Services/GradebookStudentService.swift` | Schülerverwaltung: hinzufügen, löschen, umbenennen |
| `Features/.../Services/CSVImportService.swift` | CSV-Parsing für Schüler-Import |
| `Features/.../Services/MockSeedDataService.swift` | Demo-Daten beim ersten Start |

### Migration
| Datei | Beschreibung |
|-------|-------------|
| `Features/.../Migration/GradebookMigrationService.swift` | Migriert alte Snapshot-Daten in Entities |
| `Features/.../Migration/LegacyGradebookMigration.swift` | Migriert uraltes JSON-Format |
| `Features/.../Migration/GradebookSnapshotStore.swift` | Liest alte Snapshot-Daten (nur noch für Migration) |

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

Falls der SwiftData-Store nicht geöffnet werden kann, versucht die App aktuell als letzten Notfall, die Store-Dateien zurückzusetzen und den Container neu zu erstellen. Das ist ein pragmatischer Fallback, aber noch keine produktionsreife, versionierte Migrationsstrategie.
