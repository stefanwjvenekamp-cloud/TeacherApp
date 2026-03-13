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

Current major modules in the repository include:

- Grade Management / Gradebook
- Calendar
- Documentation
- Group Assignment
- Planner
- Surveys

The most complex subsystem is the Gradebook feature.

The gradebook behaves like a structured mathematical table with a tree-based
hierarchy of areas, sub-areas and grade columns.

The architecture must preserve:

- tree integrity
- predictable rendering
- stable persistence behavior
- safe future evolution


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
Feature-oriented architecture with SwiftUI Views, ViewModels, Services and Persistence

Data structure core
Tree-based grade calculation model


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

The App layer contains only application bootstrap logic.

Responsibilities:

- application lifecycle
- ModelContainer configuration
- root view initialization
- environment setup
- migration entry flow

Examples in current project:

- `NotenverwaltungApp.swift`
- `App/Persistence/PersistenceController.swift`
- `App/Migration/MigrationGateView.swift`

The App layer must NOT contain:

- grade calculation logic
- tree mutation logic
- feature-specific rendering logic


------------------------------------------------------------
CORE LAYER
------------------------------------------------------------

Core contains fundamental educational domain concepts used across the app.

Examples:

- Teacher
- Subject
- SchoolYear
- SchoolClass
- Student

Rules:

- Core models represent domain concepts.
- They must remain UI-independent.
- They must not contain rendering logic.

Important note:

- In the current project, some core/domain models are SwiftData-backed.
- This is acceptable for the current architecture.
- Business logic must still remain outside rendering code and outside persistence glue code.


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

Current internal structure includes:

- Models
- Views
- ViewModels
- Services
- Migration

This feature owns:

- gradebook tree models
- gradebook rendering
- gradebook mutations
- gradebook persistence orchestration
- gradebook migration helpers


------------------------------------------------------------
GRADEBOOK ARCHITECTURE
------------------------------------------------------------

The gradebook system is implemented as a strict tree structure.

Every gradebook element is represented by a node.

Examples of nodes:

- grade areas
- sub-areas
- calculated aggregate nodes
- input / grade columns


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

Examples:

- area
- sub-area
- grade column

Important rule:

- every visible node owns exactly its own visual data column
- parent nodes do NOT own the data columns of their descendants

The grid is a visual projection of the tree structure.


------------------------------------------------------------
CALCULATION MODEL
------------------------------------------------------------

Grade calculations follow strict parent-child semantics.

Rule:

A parent node calculates its value ONLY from its direct children.

It must NOT calculate directly from deeper descendants.

Example:

SchoolYear
 ├ Semester1
 └ Semester2

SchoolYear calculates from:

- Semester1
- Semester2


------------------------------------------------------------
WEIGHTING
------------------------------------------------------------

Children of a parent node may have weights.

Default behavior:

When a new parent node is created,
its children receive equal weights unless explicitly changed.

Rules:

- weights are attached to the direct parent-child relation
- weights remain editable by the user
- redistribution operations must preserve tree integrity


------------------------------------------------------------
STRUCTURE TRANSFORMATIONS
------------------------------------------------------------

Structural operations must preserve tree invariants and user data.

Examples:

- inserting nodes
- deleting nodes
- moving nodes
- adding sibling areas
- restructuring subtrees

Rules:

- subtrees must remain intact
- node IDs must remain stable
- student data must not be lost unintentionally
- operations must go through feature services / interactors, not through ad hoc view mutations


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
- persistence logic
- structural mutation logic

Small rendering-specific resolver helpers are allowed if they only determine
presentation state and do not change domain behavior.


------------------------------------------------------------
COLOR OWNERSHIP MODEL
------------------------------------------------------------

Color behavior follows an explicit ownership model.

There are three rendering contexts:

1. Header tile
2. Container / L-area
3. Data column

Rules:

- each rendering context resolves color ownership independently
- color ownership must be explicit
- implicit global inheritance is not allowed

Current intended semantics:

Header tile:
- owner is the rendered node itself

Container / L-area:
- owner is the rendered node itself

Data column:
- owner is the node of that exact column itself

Important consequence:

- a parent node does NOT color descendant data columns
- a node colors only its own data column
- header and data ownership are intentionally separate concerns


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
SERVICES
------------------------------------------------------------

Services encapsulate feature operations and persistence-related domain workflows.

Examples in GradeManagement:

- `GradebookNodeService`
- `GradebookRepository`
- `GradebookStudentService`
- `GradebookTreeService`
- `GradebookDetailInteractor`

Rules:

- Views must not perform structural tree mutations directly
- services/interactors own structural mutation workflows
- repository logic must remain outside views
- feature-specific services should remain inside the feature unless truly reused elsewhere


------------------------------------------------------------
VIEW MODELS
------------------------------------------------------------

ViewModels mediate between UI and feature/domain services.

Responsibilities:

- UI state
- user interaction handling
- coordinating service/interactor calls
- presentation-specific state synchronization

They must not duplicate domain logic or calculation semantics.


------------------------------------------------------------
GRID RENDERING
------------------------------------------------------------

The gradebook grid is a visual projection of the tree.

Rules:

- grid rendering must not modify the tree
- layout must reflect node structure
- scroll and zoom systems remain independent from calculation logic
- sticky header behavior must remain rendering-only behavior
- local rendering fixes are allowed when they do not change domain semantics


------------------------------------------------------------
AI DEVELOPMENT GUARDRAILS
------------------------------------------------------------

When AI tools modify the codebase, the following rules apply.

AI must NOT:

- refactor unrelated systems
- change calculation semantics unintentionally
- change tree invariants
- introduce broad new architectural layers without explicit approval
- move feature-specific logic out of its feature without reason

AI should:

- modify the minimal set of files
- preserve tree invariants
- preserve existing UI behavior unless explicitly changing it
- reuse existing services/interactors
- keep rendering fixes local when possible


------------------------------------------------------------
BACKWARDS COMPATIBILITY
------------------------------------------------------------

New changes must not break existing gradebooks.

Structural changes must preserve:

- node IDs
- student data
- weights
- column structure
- migration safety expectations


------------------------------------------------------------
FUTURE COMPATIBILITY
------------------------------------------------------------

The architecture should remain compatible with future features such as:

- sync
- export systems
- analytics
- advanced grade calculations
- richer teacher workflows

This does not require new architecture layers today.
It requires keeping responsibilities clear and coupling controlled.


------------------------------------------------------------
CORE PRINCIPLE
------------------------------------------------------------

The gradebook behaves as a mathematical tree of weighted aggregations.

The UI visualizes this tree and its columns.

The UI must never violate:

- tree structure
- ownership semantics
- calculation semantics
- persistence safety
