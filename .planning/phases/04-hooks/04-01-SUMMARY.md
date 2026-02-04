---
phase: 04-hooks
plan: 01
subsystem: services
tags: [swiftdata, hooks, external-commands, process, automation]

# Dependency graph
requires:
  - phase: 03-02
    provides: [TransformRule SwiftData model, TransformEngine service, clipboard transform integration]
provides:
  - Hook SwiftData model for external command automation
  - HookEngine service for pattern matching and command execution
  - Integration with ClipboardMonitor for hook triggering
affects: [04-02]

# Tech tracking
tech-stack:
  added: [Process (Foundation)]
  patterns: [fire-and-forget async execution, environment variable passing]

key-files:
  created:
    - clipass/Models/Hook.swift
    - clipass/Services/HookEngine.swift
  modified:
    - clipass/Services/ClipboardMonitor.swift
    - clipass/clipassApp.swift

key-decisions:
  - "Use Process for shell command execution - cross-platform Foundation API"
  - "Fire-and-forget pattern - hooks run async on background queue, no blocking"
  - "Environment variables for content passing - CLIPASS_CONTENT and CLIPASS_SOURCE_APP"
  - "Empty pattern matches all clipboard events - allows universal hooks"

patterns-established:
  - "Hook execution after clipboard save - ensures content is persisted first"
  - "Same dependency injection pattern as TransformEngine - setModelContext, setHookEngine"
  - "Regex pattern matching with empty-matches-all semantics"

issues-created: []

# Metrics
duration: 8min
completed: 2026-02-04
---

# Phase 4: Hooks - Plan 01 Summary

**Hook engine and model for executing external scripts on clipboard events**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-04T11:15:00+07:00
- **Completed:** 2026-02-04T11:23:00+07:00
- **Tasks:** 3
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- Created Hook SwiftData model with fields: id, name, pattern, command, sourceAppFilter, isEnabled, order, createdAt
- Created HookEngine service that fetches enabled hooks, filters by app and pattern, and executes commands asynchronously
- Integrated HookEngine with ClipboardMonitor to fire hooks after clipboard save
- Connected HookEngine to app lifecycle via clipassApp.swift

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Hook SwiftData model** - `ee9933d` (feat)
2. **Task 2: Create HookEngine service** - `1038e4b` (feat)
3. **Task 3: Integrate HookEngine with ClipboardMonitor** - `4e6aafa` (feat)

## Files Created/Modified
- `clipass/Models/Hook.swift` - SwiftData @Model for hook configuration
- `clipass/Services/HookEngine.swift` - Service that executes matching hooks via Process
- `clipass/Services/ClipboardMonitor.swift` - Added hookEngine property and executeHooks call
- `clipass/clipassApp.swift` - Added hookEngine instance and injection

## Decisions Made
- Used Process (Foundation) for shell command execution - reliable cross-platform API
- Fire-and-forget execution pattern - hooks run on background queue without blocking UI
- Environment variables CLIPASS_CONTENT and CLIPASS_SOURCE_APP pass clipboard data to scripts
- Empty pattern matches all clipboard events, allowing universal hooks
- Hook execution happens after clipboard save to ensure data persistence

## Deviations from Plan

None. All tasks executed as specified.

---

**Total deviations:** 0 auto-fixed, 0 deferred
**Impact on plan:** None

## Issues Encountered
None

## Next Steps
- Plan 04-02: Hooks UI for creating and managing hooks
- Users will be able to add, edit, delete, and toggle hooks

---
*Phase: 04-hooks*
*Completed: 2026-02-04*
