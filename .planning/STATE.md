---
gsd_state_version: 1.0
milestone: v2.1
milestone_name: Developer Power Tools
status: active
stopped_at: ""
last_updated: "2026-03-19T12:30:00.000Z"
last_activity: 2026-03-19 — v2.1 roadmap created (phases 15-19)
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 10
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-19)

**Core value:** Smart transforms — auto-cleaning and formatting clipboard content before paste
**Current focus:** Phase 15 — Tags (ready to plan)

## Current Position

Phase: 15 of 19 (Tags)
Plan: —
Status: Ready to plan
Last activity: 2026-03-19 — v2.1 roadmap created, phases 15-19 defined

Progress: [░░░░░░░░░░] 0% (v2.1 milestone)

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

### Pending Todos

None.

### Blockers/Concerns

None at roadmap creation.

## Session Continuity

Last session: 2026-03-19
Stopped at: v2.1 roadmap created — phases 15-19 defined, ready to plan Phase 15
Resume file: None
