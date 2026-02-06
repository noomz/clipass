---
phase: 06-filtering
plan: 01
subsystem: filtering
tags: [SwiftData, regex, clipboard-filtering, ignore-patterns]

# Dependency graph
requires:
  - phase: 05-settings-window
    provides: Settings UI infrastructure
provides:
  - IgnoredApp SwiftData model for app-based filtering
  - IgnoredPattern SwiftData model for regex pattern filtering
  - ClipboardMonitor filtering integration
  - Regex caching for performance
affects: [06-02-ignored-apps-ui, 06-03-ignored-patterns-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Regex caching pattern for polling performance
    - Source app filtering pattern

key-files:
  created:
    - clipass/Models/IgnoredApp.swift
    - clipass/Models/IgnoredPattern.swift
  modified:
    - clipass/Services/ClipboardMonitor.swift
    - clipass/clipassApp.swift

key-decisions:
  - "Used AnyRegexOutput for cached regexes to support dynamic pattern compilation"
  - "Filter checks placed after transforms but before duplicate check"

patterns-established:
  - "Regex caching: Store compiled regexes by UUID, invalidate on pattern change"

# Metrics
duration: 2 min
completed: 2026-02-06
---

# Phase 6 Plan 01: Filtering Models Summary

**SwiftData models for IgnoredApp and IgnoredPattern with ClipboardMonitor integration for filtering clipboard content by source app and regex patterns**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-06T11:07:28Z
- **Completed:** 2026-02-06T11:09:58Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Created IgnoredApp SwiftData model for filtering by app bundle ID
- Created IgnoredPattern SwiftData model for filtering by regex patterns
- Integrated filtering logic into ClipboardMonitor with regex caching
- Both models support isEnabled flag for FILT-03 toggle functionality

## Task Commits

Each task was committed atomically:

1. **Task 1: Create IgnoredApp and IgnoredPattern models** - `ea39916` (feat)
2. **Task 2: Register models in AppServices** - `f3f78fc` (feat)
3. **Task 3: Add filtering logic to ClipboardMonitor** - `3eae1cf` (feat)

## Files Created/Modified

- `clipass/Models/IgnoredApp.swift` - SwiftData model for ignored app bundle IDs with isEnabled toggle
- `clipass/Models/IgnoredPattern.swift` - SwiftData model for content ignore patterns (regex) with isEnabled toggle
- `clipass/Services/ClipboardMonitor.swift` - Added filtering logic, regex caching, and cache invalidation method
- `clipass/clipassApp.swift` - Registered both new models in ModelContainer

## Decisions Made

- Used `Regex<AnyRegexOutput>` for cached regexes since patterns are compiled dynamically from strings
- Placed filter checks after transforms to filter on transformed content (not raw)
- Added `invalidatePatternCache()` method for future UI to call when patterns are modified

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Initial attempt used `Regex<Substring>` but Swift's dynamic regex compilation returns `Regex<AnyRegexOutput>` - fixed by updating type annotations

## Next Phase Readiness

- Models and filtering logic ready for Phase 6 Plan 02 (Ignored Apps UI)
- `invalidatePatternCache()` available for UI to call on pattern changes
- No blockers

---
*Phase: 06-filtering*
*Completed: 2026-02-06*
