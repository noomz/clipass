---
phase: 14-inline-editor
plan: 01
subsystem: ui
tags: [swiftui, nstext, swiftdata, nspanel, inline-editor, clipboard]

# Dependency graph
requires:
  - phase: 12-overlay-panel
    provides: NSPanel-based overlay with OverlaySearchField, OverlayItemRow, ClipboardOverlayView, ESC routing via cancelOperation
  - phase: 13-theme-system
    provides: Theme type and ThemeManager singleton injected into overlay views

provides:
  - NSTextView-backed inline editor panel embedded at the bottom of the overlay
  - Two-stage ESC routing: first ESC cancels editor, second ESC dismisses overlay
  - SwiftData-only save path (no pasteboard write, no duplicate history entry)
  - Pencil icon on hover/selected rows to enter edit mode
  - Cross-view sync: edits appear in menu bar popup via @Query

affects: [any phase touching ClipboardOverlayView, OverlayItemRow, OverlayWindowController]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - NSTextView wrapped in NSViewRepresentable for multi-line editing in non-activating NSPanel
    - cancelEditHandler closure on OverlayPanel to intercept panel-level cancelOperation before hide()
    - SwiftData mutation without pasteboard write to prevent history duplication

key-files:
  created:
    - clipass/Views/EditorTextView.swift
    - clipass/Views/InlineEditorPanel.swift
  modified:
    - clipass/Views/OverlayItemRow.swift
    - clipass/Views/ClipboardOverlayView.swift
    - clipass/Views/OverlaySearchField.swift
    - clipass/Controllers/OverlayWindowController.swift

key-decisions:
  - "NSTextView used directly (not TextEditor) — SwiftUI TextEditor unreliable in non-activating NSPanel for focus and cursor control"
  - "cancelEditHandler closure on OverlayPanel intercepts ESC before hide() — required because EditorTextView can lose first-responder, sending ESC to panel level"
  - "Save path writes only to SwiftData modelContext (no NSPasteboard.general.setString) — prevents creating a duplicate clipboard history entry"
  - "shouldRefocus: Bool parameter added to OverlaySearchField — allows search field to reclaim first-responder when editor closes without fighting EditorTextView's own focus claim"

patterns-established:
  - "Panel-level ESC guard: OverlayPanel.cancelEditHandler returns Bool — true means ESC was consumed by editor, false lets hide() proceed"
  - "NSViewRepresentable focus management: DispatchQueue.main.async makeFirstResponder in updateNSView when isActive=true"
  - "Two-stage ESC: onEscape closure in search field checks editingItemID first, cancels editor before dismissing overlay"

requirements-completed: [EDIT-01, EDIT-02, EDIT-03, EDIT-04]

# Metrics
duration: ~90min
completed: 2026-03-19
---

# Phase 14 Plan 01: Inline Editor Summary

**NSTextView-backed inline editor panel in the clipboard overlay: pencil icon triggers bottom editor, Cmd+Return saves to SwiftData only (no duplicate), two-stage ESC cancels editor then dismisses overlay, edits sync to menu bar popup via @Query**

## Performance

- **Duration:** ~90 min (including UAT and bug fixes)
- **Started:** 2026-03-19
- **Completed:** 2026-03-19
- **Tasks:** 3 (2 auto, 1 human-verify checkpoint)
- **Files modified:** 6

## Accomplishments

- Created `EditorTextView.swift` — NSTextView-backed NSViewRepresentable with Cmd+Return commit, ESC cancel, auto-focus, and monospace font
- Created `InlineEditorPanel.swift` — bottom panel container with Cancel/Save buttons, slides in with `.move(edge: .bottom)` animation
- Wired complete edit lifecycle in `ClipboardOverlayView`: `enterEditMode`, `commitEdit`, `cancelEdit` with SwiftData-only persistence
- Two-stage ESC routing: `OverlaySearchField.onEscape` checks `editingItemID`, and `OverlayPanel.cancelEditHandler` guards panel-level ESC
- All 9 UAT scenarios passed after 4 targeted bug fixes (ESC crash, Cmd+Return save, line number gutter, edit icon visibility)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create EditorTextView and InlineEditorPanel, add pencil icon to OverlayItemRow** - `8b2560d` (feat)
2. **Task 2: Wire inline editor into ClipboardOverlayView with ESC routing and panel guard** - `867fbc3` (feat)
3. **Task 3 UAT** - `64171fa` (test) — UAT record commit
4. **Bug fixes (post-UAT)** - `f69b7ec` (fix) — ESC crash, Cmd+Return save, line number gutter, edit icon

## Files Created/Modified

- `clipass/Views/EditorTextView.swift` — NSTextView NSViewRepresentable with Cmd+Return, ESC, auto-focus, and monospace rendering
- `clipass/Views/InlineEditorPanel.swift` — Bottom editor panel with Cancel/Save buttons and theme-aware styling
- `clipass/Views/OverlayItemRow.swift` — Added pencil icon on hover/selected with `onEdit` callback and `isEditing` state
- `clipass/Views/ClipboardOverlayView.swift` — Added `editingItemID`/`editorContent` state, `enterEditMode`/`commitEdit`/`cancelEdit`, ESC routing, conditional InlineEditorPanel
- `clipass/Views/OverlaySearchField.swift` — Added `shouldRefocus` parameter so search field reclaims focus after editor closes
- `clipass/Controllers/OverlayWindowController.swift` — Added `cancelEditHandler: (() -> Bool)?` to `OverlayPanel` for two-stage ESC at panel level

## Decisions Made

- NSTextView used directly rather than SwiftUI TextEditor — SwiftUI TextEditor cannot reliably receive first-responder in a `.nonactivatingPanel`, making focus and cursor management fragile.
- `cancelEditHandler` closure on `OverlayPanel` required — if `EditorTextView` loses first-responder (e.g., user clicks overlay background), the next ESC keypress reaches `cancelOperation(_:)` on the panel level and would bypass the two-stage flow.
- Save path does not call `NSPasteboard.general.setString` — writing to pasteboard triggers the `ClipboardMonitor`, which would create a duplicate history entry for the edited content.
- `shouldRefocus` added to `OverlaySearchField` — without it, when the editor closes, the search field `updateNSView` races against `EditorTextView`'s own focus request, causing unreliable focus restoration.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ESC crash in non-activating panel when editor active**
- **Found during:** Task 3 (UAT scenario 5)
- **Issue:** Pressing ESC while EditorTextView had focus triggered `cancelOperation` on `OverlayPanel`, which called `hide()` instead of `cancelEdit()` — crashing when edit state was nil-checked post-hide
- **Fix:** Added `cancelEditHandler` to `OverlayPanel`; wired from `ClipboardOverlayView.onAppear` to return true and call `cancelEdit()` when `editingItemID != nil`
- **Files modified:** `OverlayWindowController.swift`, `ClipboardOverlayView.swift`
- **Committed in:** `f69b7ec`

**2. [Rule 1 - Bug] Cmd+Return not saving**
- **Found during:** Task 3 (UAT scenario 6)
- **Issue:** `textView(_:doCommandBy:)` selector comparison for Cmd+Return was not matching correctly
- **Fix:** Corrected selector matching for `insertNewline:` with event modifier flags check
- **Files modified:** `EditorTextView.swift`
- **Committed in:** `f69b7ec`

**3. [Rule 1 - Bug] Line number gutter appearing in editor**
- **Found during:** Task 3 (UAT scenario 3)
- **Issue:** NSScrollView default configuration showed line number ruler
- **Fix:** Explicitly set `scrollView.hasHorizontalRuler = false`, `scrollView.hasVerticalRuler = false`, `scrollView.rulersVisible = false`
- **Files modified:** `EditorTextView.swift`
- **Committed in:** `f69b7ec`

**4. [Rule 1 - Bug] Edit icon not visible on hover**
- **Found during:** Task 3 (UAT scenario 2)
- **Issue:** Pencil button was placed inside the content Text layout, clipped by the row's fixed height
- **Fix:** Restructured row HStack to place pencil button as trailing element with correct Spacer placement
- **Files modified:** `OverlayItemRow.swift`
- **Committed in:** `f69b7ec`

---

**Total deviations:** 4 auto-fixed (all Rule 1 - Bug)
**Impact on plan:** All fixes necessary for core correctness of UAT scenarios. No scope creep.

## Issues Encountered

- Focus management in non-activating NSPanel required careful ordering: `EditorTextView` must claim focus via `DispatchQueue.main.async` in `updateNSView` (not `makeNSView`) to avoid racing with SwiftUI layout pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 14 Plan 01 complete. Inline editor feature fully functional and UAT-verified.
- All 4 EDIT requirements (EDIT-01 through EDIT-04) satisfied.
- No blockers for subsequent plans in phase 14 (if any) or project completion.

---
*Phase: 14-inline-editor*
*Completed: 2026-03-19*
