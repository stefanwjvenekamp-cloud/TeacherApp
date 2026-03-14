# Architecture Rules — Notenverwaltung

This document defines the architectural rules of the project.

All code modifications should follow these rules unless explicitly instructed otherwise.

Goals:

- long-term stability
- predictable behavior
- maintainable architecture
- safe AI-assisted development


------------------------------------------------------------
PROJECT OVERVIEW
------------------------------------------------------------

Notenverwaltung is a SwiftUI-based teacher application with a feature-oriented structure.

Current modules in the repository include:

- Grade Management / Gradebook
- Calendar
- Documentation
- Group Assignment
- Planner
- Surveys

The most mature subsystem is the Grade Management feature.

The architecture must preserve:

- stable student identity
- clear separation between person and participation context
- predictable gradebook behavior
- explicit import review instead of blind data merges
- safe future evolution across modules


------------------------------------------------------------
TECHNOLOGY STACK
------------------------------------------------------------

Language
Swift

UI Framework
SwiftUI

Persistence
SwiftData

Architecture style
Feature-oriented architecture with SwiftUI Views, ViewModels, Services, Interactors and SwiftData-backed domain entities

Data structure core

- central educational domain models
- enrollment-based identity/context separation
- tree-based grade calculation model


------------------------------------------------------------
PROJECT STRUCTURE
------------------------------------------------------------

The repository follows a feature-oriented structure.

Top-level structure:

App/
Core/
Features/

Notes:

- `App/` contains bootstrap and application composition.
- `Core/` contains shared educational domain concepts.
- `Features/` contains functional modules.
- There is currently no strong requirement for a broad `Shared/` layer.
  Feature-specific logic should stay inside its feature unless it is truly reused.


------------------------------------------------------------
APP LAYER
------------------------------------------------------------

The App layer contains only bootstrap logic.

Responsibilities:

- application lifecycle
- ModelContainer configuration
- root view initialization
- environment setup
- migration / startup flow orchestration

Examples in current project:

- `NotenverwaltungApp.swift`
- `App/Persistence/PersistenceController.swift`
- `App/Migration/MigrationGateView.swift`

The App layer must NOT contain:

- grade calculation logic
- CSV matching logic
- feature-specific rendering logic
- gradebook mutation workflows


------------------------------------------------------------
CORE LAYER
------------------------------------------------------------

Core contains educational domain concepts that are relevant beyond one single view.

Important current concepts include:

- Teacher
- Subject
- SchoolYear
- Term
- SchoolClass
- Course
- Student
- ClassEnrollment

Rules:

- Core models represent domain concepts.
- They must remain UI-independent.
- They must not contain rendering logic.
- Domain identity must not be modeled through display strings.

Important current identity rule:

- `Student` is the central person identity.
- `SchoolClass` is an organizational context.
- `ClassEnrollment` models the participation of one `Student` in one `SchoolClass`.
- Group membership must not be modeled directly on `Student` through duplicated person objects.

Explicitly forbidden:

- using names as identity keys
- treating name equality as identity equality
- duplicating persons only because they appear in multiple class contexts


------------------------------------------------------------
IDENTITY AND MEMBERSHIP MODEL
------------------------------------------------------------

The central domain structure is:

Student
   │
ClassEnrollment
   │
SchoolClass
   │
GradebookRowEntity
   │
GradeEntry

Rules:

- `Student` owns the stable person identity.
- `ClassEnrollment` owns the participation context.
- `GradebookRowEntity` belongs to an enrollment, not directly to a person.
- `GradeEntry` belongs to a gradebook row and therefore inherits the correct class context through that row.

Consequences:

- the same `Student` may appear in multiple classes through multiple enrollments
- the same `Student` may later be reused across modules
- UI may still work with `studentID` as a derived identifier
- persistence and domain workflows must resolve class context through enrollment, not through the raw name


------------------------------------------------------------
FEATURE LAYER
------------------------------------------------------------

Every functional module lives inside `Features/`.

Examples in current repository:

- `Features/GradeManagement`
- `Features/Calendar`
- `Features/Documentation`
- `Features/GroupAssignment`
- `Features/Planner`
- `Features/Surveys`

A feature may contain:

- `Models/`
- `Views/`
- `ViewModels/`
- `Services/`
- `Migration/`

Rules:

- Features should be internally cohesive.
- Feature-specific logic should remain inside the feature.
- Features should not directly depend on implementation details of other features.
- Cross-feature reuse should be extracted only when it is truly shared.


------------------------------------------------------------
GRADE MANAGEMENT FEATURE
------------------------------------------------------------

`Features/GradeManagement` is the most complex and most important feature.

This feature currently owns:

- gradebook tree models
- gradebook rendering
- gradebook mutations
- student-to-class workflows
- CSV import review and matching pipeline
- gradebook persistence orchestration


------------------------------------------------------------
GRADEBOOK ARCHITECTURE
------------------------------------------------------------

The gradebook system combines two different but connected structures:

1. a strict tree of grade columns / aggregations
2. a row-based projection of students-in-context

The tree defines:

- hierarchy
- weights
- calculations
- header projection

The row system defines:

- which enrolled student appears in a given class tab
- where cell values and grade entries belong

These structures must not be collapsed into one another.


------------------------------------------------------------
TREE INVARIANTS
------------------------------------------------------------

The following rules must always hold:

1. The structure is a directed tree.
2. Every non-root node has exactly one parent.
3. The root node has no parent.
4. Cycles are not allowed.
5. Node IDs must remain stable across structural edits.
6. Structural operations must preserve subtree integrity.


------------------------------------------------------------
COLUMN SEMANTICS
------------------------------------------------------------

Each visible node corresponds to exactly one data column in the grid.

Important rule:

- every visible node owns exactly its own visual data column
- parent nodes do NOT own the data columns of their descendants

The grid is a visual projection of the tree structure.


------------------------------------------------------------
ROW AND TAB SEMANTICS
------------------------------------------------------------

Rows are not pure UI artifacts.

Rules:

- a `GradebookRowEntity` belongs to exactly one enrollment context
- rows are created per class / tab context
- row visibility in the table must come from `GradebookRowEntity -> ClassEnrollment -> Student`
- a row must never be treated as a free-floating student record

Important consequence:

- a visible student in a gradebook table is a student-in-context, not just a bare person object


------------------------------------------------------------
CALCULATION MODEL
------------------------------------------------------------

Grade calculations follow strict parent-child semantics.

Rule:

A parent node calculates its value ONLY from its direct children.

It must NOT calculate directly from deeper descendants.


------------------------------------------------------------
WEIGHTING
------------------------------------------------------------

Children of a parent node may have weights.

Rules:

- weights are attached to the direct parent-child relation
- weights remain editable by the user
- redistribution operations must preserve tree integrity


------------------------------------------------------------
CSV IMPORT ARCHITECTURE
------------------------------------------------------------

CSV import is implemented as an explicit staged pipeline.

Current pipeline:

CSV
→ `CSVImportCandidate`
→ `CSVImportMatchResult`
→ `CSVImportResolution`
→ commit

Rules:

- parsing, matching, resolution and persistence must remain separate steps
- import must not create domain data before validation and user review
- matching may suggest candidates but must not silently decide identity
- resolution must be explicit before commit
- incomplete resolutions must not be committed

Explicitly forbidden:

- blind auto-merge on name equality
- using names as unique keys
- hiding ambiguity from the user


------------------------------------------------------------
MATCHING RULES
------------------------------------------------------------

Current matching is intentionally conservative.

Allowed match qualities currently include:

- `exact`
- `normalized`
- `legacySegmented`
- `germanNormalized`

Rules:

- stronger match qualities must keep their precedence
- additive matching rules must not silently replace stronger existing matches
- matching remains a suggestion layer, not a truth layer


------------------------------------------------------------
SERVICES AND INTERACTORS
------------------------------------------------------------

Services encapsulate feature operations and persistence-related domain workflows.

Examples in GradeManagement:

- `GradebookRepository`
- `GradebookNodeService`
- `GradebookStudentService`
- `GradebookTreeService`
- `GradebookDetailInteractor`
- `CSVImportService`

Rules:

- views must not perform structural mutations directly
- repository logic must remain outside views
- import commit workflows must reuse existing repository/service behavior where possible
- feature-specific services should remain inside the feature unless truly reused elsewhere


------------------------------------------------------------
VIEW MODELS
------------------------------------------------------------

ViewModels mediate between UI and feature/domain services.

Responsibilities:

- UI state
- interaction handling
- coordinating service/interactor calls
- presentation-specific synchronization

They must not duplicate domain semantics.


------------------------------------------------------------
RENDERING SEPARATION
------------------------------------------------------------

Rendering logic must remain separate from domain logic.

Rendering code may contain:

- layout
- positioning
- drawing cells
- colors
- interaction handling
- local presentation helpers

Rendering code must NOT contain:

- grade calculation logic
- import matching logic
- persistence logic
- structural mutation workflows


------------------------------------------------------------
SWIFTDATA RULES
------------------------------------------------------------

SwiftData is used for persistence and storage integration.

Rules:

SwiftData-backed models must NOT contain:

- rendering logic
- view-specific behavior

Business logic should live in services, interactors or pure model helpers where appropriate.

Important note:

- The current project is not fully persistence-ignorant.
- This is acceptable.
- New code should not increase coupling between rendering and persistence.


------------------------------------------------------------
BACKWARDS COMPATIBILITY
------------------------------------------------------------

Backwards compatibility should be treated pragmatically.

Rules:

- existing stable feature behavior should not be broken without reason
- data migrations should be deliberate, not accidental
- temporary compatibility paths are acceptable during refactors
- compatibility code should be removed once the new architecture is stable and verified


------------------------------------------------------------
FUTURE COMPATIBILITY
------------------------------------------------------------

The architecture should remain compatible with future features such as:

- cross-module student reuse
- export systems
- sync
- analytics
- richer teacher workflows

This does not require new architecture layers today.
It requires keeping responsibilities clear and coupling controlled.


------------------------------------------------------------
AI DEVELOPMENT GUARDRAILS
------------------------------------------------------------

When AI tools modify the codebase, the following rules apply.

AI must NOT:

- refactor unrelated systems
- change calculation semantics unintentionally
- break identity/enrollment rules
- introduce silent import merges
- introduce broad new architectural layers without explicit approval

AI should:

- modify the minimal set of files
- preserve tree invariants
- preserve identity and enrollment semantics
- preserve existing UI behavior unless explicitly changing it
- reuse existing services/interactors


------------------------------------------------------------
CORE PRINCIPLE
------------------------------------------------------------

The app combines a stable person identity model, explicit participation context and a mathematical gradebook tree.

The UI visualizes these structures.

The UI must never violate:

- identity semantics
- enrollment semantics
- tree structure
- ownership semantics
- calculation semantics
- persistence safety
