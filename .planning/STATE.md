---
gsd_state_version: 1.0
milestone: v2.1
milestone_name: Developer Power Tools
status: unknown
stopped_at: Completed 15-02 auto tasks (awaiting human verify checkpoint)
last_updated: "2026-03-20T08:21:25.613Z"
progress:
  total_phases: 5
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-19)

**Core value:** Smart transforms — auto-cleaning and formatting clipboard content before paste
**Current focus:** Phase 15 — tags

## Current Position

Phase: 15 (tags) — EXECUTING
Plan: 1 of 2

## Performance Metrics

**Velocity:**

- Total plans completed: 16 (v1.0: 9, v1.1: 7, v2.0: 5 — phases 12-14)
- Average duration: ~4 min/plan
- Total execution time: ~55 min

**By Phase (v2.0 reference):**

| Phase | Plans | Notes |
|-------|-------|-------|
| 12. Overlay Panel | 2/2 | NSPanel, SwiftUI overlay view |
| 13. Theme System | 2/2 | ThemeManager, Appearance settings |
| 14. Inline Editor | 1/1 | NSTextView, ESC handling, SwiftData round-trip |
| Phase 15-tags P01 | 7 | 2 tasks | 3 files |
| Phase 15-tags P02 | 4 | 2 tasks | 6 files |

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full list.

Recent decisions relevant to v2.1:

- [v2.0 arch]: NSTextView used directly (not SwiftUI TextEditor) — unreliable focus in non-activating NSPanel
- [v2.0 arch]: Overlay must be NSPanel subclass for non-activating floating behavior
- [v2.1 arch]: CLI is a separate executableTarget (clipass-cli) sharing ClipassShared library with the app
- [v2.1 arch]: Unix domain socket at ~/Library/Application Support/clipass/clipass.sock — 4-byte length-prefix framing
- [v2.1 arch]: All SwiftData operations dispatch to @MainActor from socket background thread
- [v2.1 arch]: Action chains are manual-only — cannot be triggered by pub/sub (security)
- [v2.1 arch]: Tags use SwiftData implicit many-to-many; additive schema migration (lightweight)
- [Phase 15-tags]: @Relationship(inverse: \Tag.items) declared only on ClipboardItem.tags — SwiftData many-to-many requires inverse annotation on exactly one side
- [Phase 15-tags]: Additive schema migration: adding Tag.self to ModelContainer with no VersionedSchema — SwiftData handles lightweight migration automatically
- [Phase 15-tags]: TagBadgesRow uses overflowColor: Color param instead of theme: Theme — enables reuse in MenuBarExtra context where ThemeManager unavailable
- [Phase 15-tags]: Flat tag buttons in HistoryItemRow context menu — MenuBarExtra submenu actions silently fail (known SwiftUI bug)

### Pending Todos

None.

### Blockers/Concerns

None at roadmap creation.

## Session Continuity

Last session: 2026-03-20T08:21:25.605Z
Stopped at: Completed 15-02 auto tasks (awaiting human verify checkpoint)
Resume file: None
