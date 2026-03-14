# Gradebook Rules — Notenverwaltung

This document defines the functional and structural rules of the Gradebook
system used in the Notenverwaltung application.

These rules define how the grade table behaves internally and how structural
changes must be implemented.

The gradebook is NOT a spreadsheet.

It is a **tree of weighted aggregations rendered as a table projection**.

The table is only a visual projection of the tree structure.

Important clarification:

The gradebook is not only a tree of columns.
It also has a row context based on enrolled students.

Current domain chain:

Student
   │
ClassEnrollment
   │
SchoolClass
   │
GradebookRowEntity
   │
GradeEntry


------------------------------------------------------------
CORE CONCEPT
------------------------------------------------------------

The gradebook is a hierarchical tree of nodes.

Each visible node corresponds to exactly one visual data column in the grid.

Nodes may represent:

- grade areas
- sub-areas
- calculated aggregate nodes
- input grade columns

Important principle:

- the tree is the source of truth
- the grid is only a projection of that tree
- row context is derived from enrolled students, not from display names


------------------------------------------------------------
TREE STRUCTURE
------------------------------------------------------------

The gradebook uses a strict tree structure.

Rules:

1. Every non-root node has exactly one parent.
2. The root node has no parent.
3. Cycles are not allowed.
4. Node IDs must remain stable.
5. Structural edits must preserve subtree integrity.
6. Reordering or moving nodes must not create duplicate ownership or detached subtrees.

Example:

Root
 └ SchoolYear
    ├ Semester1
    │  ├ Written
    │  │  ├ Exam1
    │  │  └ Exam2
    │  └ Oral
    │     ├ Contribution1
    │     └ Contribution2
    └ Semester2
       ├ Written
       └ Oral


------------------------------------------------------------
ROOT NODE
------------------------------------------------------------

The root node represents the entire gradebook tree.

Important rules:

- The root node is not a regular domain column owner.
- The root node does not own a data column in the student data area.
- The root node may still participate in header projection and layout.
- All top-level grade areas are children of the root.

Practical consequence:

- the root may appear in the header rendering structure
- the root must never own student data cells


------------------------------------------------------------
COLUMN MODEL
------------------------------------------------------------

Each visible node corresponds to exactly one column.

Examples:

Area node → one column
Sub-area node → one column
Grade column node → one column

Important rules:

- each visible node owns exactly its own column
- parent nodes do NOT own descendant columns
- descendant columns remain owned by the descendant nodes themselves
- column ownership is never shared

This is a core semantic rule of the current project.


------------------------------------------------------------
ROW CONTEXT
------------------------------------------------------------

Rows in the visible table are context-bound.

Rules:

- a visible row belongs to a `GradebookRowEntity`
- a `GradebookRowEntity` belongs to a `ClassEnrollment`
- a `ClassEnrollment` belongs to exactly one `Student` and one `SchoolClass`
- the gradebook must not treat a row as a free-floating person record

Important consequence:

- the visible student name in the table is a projection of
  `GradebookRowEntity -> ClassEnrollment -> Student`
- class context must come from the enrollment, not from the name
- UI may still use `studentID` as a derived identifier, but row ownership remains enrollment-based


------------------------------------------------------------
HEADER PROJECTION
------------------------------------------------------------

The header is a projection of tree structure, depth and column ownership.

Rules:

- header rows visualize hierarchy depth
- a node may visually span across its projected subtree width in the header
- a node may also have its own local column width within that projection
- header rendering must never change tree semantics
- header layout must remain a pure visualization concern

Important clarification:

A parent header may visually cover:

- its own local column region
- the projected width of child headers

This does NOT mean the parent owns child data columns.


------------------------------------------------------------
DATA COLUMN PROJECTION
------------------------------------------------------------

The student data area is column-owned, not subtree-owned.

Rules:

- each data cell belongs to exactly one node column
- the owner of a data cell is the node of that exact column
- parent nodes do NOT own descendant data cells
- no ancestor-based ownership is allowed in the data area
- no descendant-based inheritance is allowed in the data area

Practical consequence:

If a cell belongs to node `X`,
then only node `X` may own that cell.

Additional context rule:

- a data cell also belongs to exactly one row context
- a row context must remain attached to the correct enrollment
- no cell may survive detached from both its node owner and its row owner


------------------------------------------------------------
CALCULATION MODEL
------------------------------------------------------------

The gradebook uses parent-child aggregation.

Rule:

A parent node calculates its value only from its direct children.

Example:

SchoolYear
 ├ Semester1
 └ Semester2

SchoolYear = weighted(Semester1, Semester2)

Important rules:

- a parent must never calculate directly from deeper descendants
- deep descendants contribute only through the intermediate parent structure
- calculation semantics must remain independent from rendering semantics


------------------------------------------------------------
WEIGHTING
------------------------------------------------------------

Children of a parent node may have weights.

Rules:

- weights belong to the parent-child relation
- weights determine contribution to the parent result
- weights remain editable by the user
- redistribution must preserve tree structure

Default behavior:

When a new parent is created, children receive equal weights unless explicitly changed.

Example:

Parent
 ├ Child A (50%)
 └ Child B (50%)


------------------------------------------------------------
NODE TYPES
------------------------------------------------------------

The gradebook contains two conceptual node types.

INPUT NODE

Represents a column where grades are entered directly.

Examples:

- Exam1
- OralContribution

CALCULATION NODE

Represents a calculated aggregate.

Examples:

- Written
- Oral
- Semester
- SchoolYear

Important rule:

- node type affects calculation behavior
- node type must not change column ownership rules
- node type must not change row ownership rules


------------------------------------------------------------
STRUCTURAL OPERATIONS
------------------------------------------------------------

The gradebook allows structural changes.

Examples:

- insert node
- delete node
- move node
- create sibling node
- create parent node

Rules:

- subtree structure must remain intact
- node IDs must remain stable
- student data must remain attached to the correct column owner
- column order must remain deterministic
- structural changes must not silently destroy child relationships

Structural mutations must preserve:

- tree invariants
- column ownership
- calculation semantics
- row-to-enrollment consistency


------------------------------------------------------------
IDENTITY SAFETY
------------------------------------------------------------

The gradebook must never infer person identity from the visible name alone.

Rules:

- names are display values, not identity keys
- equal names do not imply equal students
- rows must not be merged automatically because two names look equal
- enrollment context must remain explicit and stable


------------------------------------------------------------
IMPORT SAFETY
------------------------------------------------------------

CSV import may feed the gradebook, but import semantics must remain explicit.

Rules:

- import matching may suggest existing students
- import matching must not silently decide identity
- review and resolution happen before commit
- committed rows must still be created through valid enrollment context

Practical consequence:

- the gradebook table only shows committed rows
- import candidates and match suggestions are not gradebook rows
- persisted identity


------------------------------------------------------------
MERGING / RESTRUCTURING AREAS
------------------------------------------------------------

Sibling nodes may be restructured under a new parent node if the operation
preserves tree invariants.

Example:

Before:

Root
 ├ Semester1
 └ Semester2

After:

Root
 └ SchoolYear
    ├ Semester1
    └ Semester2

Rules:

- merged nodes become children of the new parent
- subtree structures remain unchanged below the moved nodes
- weights default to equal distribution unless explicitly set otherwise
- existing node IDs of moved nodes must remain stable

Important note:

This is a supported structural transformation pattern, not permission for
arbitrary flattening or semantic reinterpretation.


------------------------------------------------------------
GRID PROJECTION
------------------------------------------------------------

The visual grade table is a projection of the tree.

Rules:

- column order reflects tree order
- each visible node produces exactly one visual data column
- grid rendering must not mutate the tree
- grid layout decisions must not change ownership semantics

Important clarification:

The grid may visually look spreadsheet-like,
but it must not behave like a free spreadsheet.


------------------------------------------------------------
HEADER STRUCTURE
------------------------------------------------------------

Headers represent hierarchical structure only.

Rules:

- parent headers visualize hierarchy and projected width
- header rendering must not affect calculations
- header rendering must not affect node relationships
- header ownership must remain local to the rendered node

This means:

- a node colors its own header tile
- a node colors its own container / L-area
- a node does NOT color another node’s header tile


------------------------------------------------------------
DATA CELLS
------------------------------------------------------------

Each data cell belongs to exactly one column.

Rules:

- the column node is the only owner of the cell
- parent nodes do not own descendant cells
- sibling nodes do not influence each other’s ownership
- cell ownership is resolved directly from the column node, not by walking ancestors for ownership inheritance

This rule is strict and must not be weakened by rendering shortcuts.


------------------------------------------------------------
COLOR OWNERSHIP
------------------------------------------------------------

Color follows an explicit ownership model.

There are three rendering contexts:

1. Header tile
2. Container / L-area
3. Data column

Ownership rules:

Header tile:
- owned by the rendered node itself

Container / L-area:
- owned by the rendered node itself

Data column:
- owned only by the node of that exact column

Important consequences:

- parent nodes do NOT color descendant data columns
- parent nodes do NOT color child headers
- implicit color inheritance is not allowed
- color ownership must be resolved explicitly per rendering context

Color behavior must follow ownership,
not visual proximity.


------------------------------------------------------------
RENDERING RULES
------------------------------------------------------------

Rendering must remain a pure visualization of the tree.

Rendering may contain:

- layout
- positioning
- drawing
- local presentation resolvers
- scroll synchronization
- zoom behavior
- sticky header behavior

Rendering must NOT:

- modify the tree
- calculate grades
- mutate node relationships
- redefine ownership semantics

Resolver helpers are allowed if they remain presentation-only and context-specific.


------------------------------------------------------------
STRUCTURE SAFETY
------------------------------------------------------------

Structural changes must be safe.

Operations must preserve:

- node IDs
- student data attachment to the correct node columns
- weights unless explicitly changed
- column order
- subtree integrity

Migration and recovery paths should minimize data loss,
but normal gradebook operations must preserve user data by design.


------------------------------------------------------------
PERSISTENCE INTERACTION
------------------------------------------------------------

Persistence must store the gradebook faithfully,
but persistence rules must not redefine gradebook semantics.

Rules:

- stored entities must preserve node identity
- stored entities must preserve parent-child structure
- stored entities must preserve column semantics
- persistence code must not introduce alternate ownership rules

Tree semantics are defined by the gradebook model,
not by storage format.


------------------------------------------------------------
FINAL PRINCIPLE
------------------------------------------------------------

The gradebook behaves as a **tree of weighted grade aggregations projected as a table**.

The tree defines:

- structure
- ownership
- calculation semantics

The UI only visualizes that structure.

All changes must preserve:

- tree invariants
- direct-child calculation semantics
- one-node-one-column ownership
- explicit rendering ownership
