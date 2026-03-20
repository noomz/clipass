---
phase: 15-tags
plan: "01"
subsystem: database
tags: [swiftdata, swift, model, many-to-many, migration]

# Dependency graph
requires: []
provides:
  - "Tag @Model with id, name, colorHex, createdAt, items relationship"
  - "ClipboardItem.tags @Relationship(inverse: \\Tag.items)"
  - "Tag.self registered in ModelContainer for automatic lightweight migration"
  - "8-color presetColors palette and randomPresetColor() helper"
affects:
  - 15-tags plan 02 (Tag UI — TagFilterBar, TagPicker, TagEditorSheet)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SwiftData many-to-many: @Relationship(inverse:) declared only on the owning side (ClipboardItem), not on Tag"
    - "Additive schema migration: adding Tag.self to ModelContainer is sufficient — no VersionedSchema required"

key-files:
  created:
    - clipass/Models/Tag.swift
  modified:
    - clipass/Models/ClipboardItem.swift
    - clipass/clipassApp.swift

key-decisions:
  - "@Relationship(inverse: \\Tag.items) declared only on ClipboardItem.tags — Tag.items is a plain [ClipboardItem] array with no macro"
  - "No VersionedSchema or SchemaMigrationPlan: additive model addition is handled by SwiftData lightweight migration automatically"
  - "Default colorHex is #3a8fd4 (blue) — matches the presetColors mid-blue entry"

patterns-established:
  - "Tag color palette: 8 saturated mid-range hex values stored as String, resolved to Color via existing Color(hex:) extension in Theme.swift"

requirements-completed: [TAG-01, TAG-02]

# Metrics
duration: 7min
completed: 2026-03-20
---

# Phase 15 Plan 01: Tag SwiftData Model Summary

**SwiftData Tag model with many-to-many relationship to ClipboardItem, 8-color preset palette, and automatic lightweight ModelContainer migration**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-20T08:11:46Z
- **Completed:** 2026-03-20T08:13:05Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Created Tag.swift with @Model: id, name, colorHex, createdAt, items (plain [ClipboardItem], no @Relationship macro on this side)
- Added @Relationship(inverse: \Tag.items) var tags: [Tag] = [] to ClipboardItem — correct SwiftData many-to-many pattern
- Added static presetColors (8 entries) and randomPresetColor() helper to Tag extension
- Registered Tag.self in both ModelContainer init calls (primary and fallback) in clipassApp.swift

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Tag model and wire ClipboardItem relationship** - `585de95` (feat)
2. **Task 2: Register Tag in ModelContainer** - `ec9e2ea` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `clipass/Models/Tag.swift` — New @Model with id, name, colorHex, createdAt, items relationship and color palette
- `clipass/Models/ClipboardItem.swift` — Added @Relationship(inverse: \Tag.items) var tags: [Tag] = []
- `clipass/clipassApp.swift` — Added Tag.self to both ModelContainer initializer calls

## Decisions Made

- `@Relationship(inverse: \Tag.items)` is declared only on `ClipboardItem.tags`. `Tag.items` is a plain `[ClipboardItem] = []` array — SwiftData's implicit many-to-many requires the inverse annotation on exactly one side.
- Additive schema migration: no VersionedSchema or SchemaMigrationPlan needed. Adding a new model type to ModelContainer is handled automatically by SwiftData's lightweight migration.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Tag persistence layer is fully established; plan 02 (Tag UI) can build TagFilterBar, TagPicker, and TagEditorSheet directly on top of this model.
- No blockers or concerns.

---
*Phase: 15-tags*
*Completed: 2026-03-20*
