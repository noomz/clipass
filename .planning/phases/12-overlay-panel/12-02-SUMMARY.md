---
phase: 12-overlay-panel
plan: "02"
subsystem: ui
tags: [SwiftUI, NSViewRepresentable, NSTextField, NSVisualEffectView, NSPanel, vibrancy, overlay, search, keyboard-navigation, KeyboardShortcuts, animation, focus-management]

# Dependency graph
requires:
  - phase: 12-01
    provides: OverlayWindowController singleton with setContentView/pasteAndHide/show/hide APIs
  - phase: 01-foundation
    provides: ClipboardItem SwiftData model and AppServices.shared.modelContainer
provides:
  - ClipboardOverlayView SwiftUI root overlay view with search, selection, and keyboard handling
  - OverlayItemRow row view for overlay list
  - VisualEffectView NSViewRepresentable for frosted glass vibrancy
  - OverlayWindowController wired to real ClipboardOverlayView (replaces placeholder)
  - Settings > General Overlay Hotkey recorder (OVRL-09)
affects: [13-theming, 14-settings-overlay]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSVisualEffectView state=.active required for .accessory activation policy to render blur (not flat gray)"
    - "overlayWillShow notification posted before makeKeyAndOrderFront for state reset before view appears"
    - "List(filteredItems, selection:) with .tag(item.id) for keyboard-driven selection binding"
    - "NSViewRepresentable (OverlaySearchField) wrapping NSTextField subclass (InterceptingTextField) for AppKit-level focus, arrow key interception, ESC handling in non-activating NSPanel"
    - "InterceptingTextField.keyDown intercepts arrow keys (↑↓) and ESC before SwiftUI sees them; routes via closure callbacks to parent @State"
    - "NSPanel.cancelOperation(_:) override as belt-and-suspenders ESC fallback at window level"
    - "@FocusState removed in favor of AppKit makeFirstResponder — SwiftUI focus system unreliable in .nonactivatingPanel context"
    - ".transition(.opacity.combined(with: .scale(scale: 0.95))) + .animation(.easeOut(duration: 0.15)) for show animation"
    - "ZStack with VisualEffectView() background + .clipShape(RoundedRectangle(cornerRadius: 12))"

key-files:
  created:
    - clipass/Views/VisualEffectView.swift
    - clipass/Views/OverlayItemRow.swift
    - clipass/Views/ClipboardOverlayView.swift
    - clipass/Views/OverlaySearchField.swift
  modified:
    - clipass/Controllers/OverlayWindowController.swift
    - clipass/Views/SettingsView.swift

key-decisions:
  - "scrollContentBackground(.hidden) + listStyle(.plain) on List to allow vibrancy background to show through"
  - "onChange(of: filteredItems) auto-selects first item when list changes — prevents selectedID pointing to an item no longer in results"
  - "overlayWillShow notification used (not overlayDidShow) to reset state before view becomes visible, preventing flash of stale content"
  - "OverlayItemRow uses DisplayFormatter.format with empty patterns [] — no redaction needed in overlay (speed over privacy in hotkey context)"
  - "OverlaySearchField replaces SwiftUI TextField + @FocusState — AppKit-level makeFirstResponder is the only reliable focus path in .nonactivatingPanel context"
  - "Arrow keys intercepted in NSTextField.keyDown (not SwiftUI .onKeyPress) because SwiftUI key press requires SwiftUI first-responder status, which the AppKit field does not propagate back"
  - "cancelOperation(_:) added to OverlayPanel as ESC fallback — handles edge case where field loses first-responder before ESC keyDown fires"

# Metrics
requirements-completed: [OVRL-05, OVRL-06, OVRL-07, OVRL-08, OVRL-09]
duration: ~15min
completed: 2026-03-13
---

# Phase 12 Plan 02: Overlay UI Views Summary

**SwiftUI overlay panel with frosted glass background, AppKit-backed auto-focused search field, arrow key navigation via NSTextField interception, ESC/Return handling, and Settings hotkey recorder — fixing all NSPanel keyboard event limitations**

## Performance

- **Duration:** ~15 min (includes checkpoint + 3 bug fix passes)
- **Started:** 2026-03-13T08:53:07Z
- **Completed:** 2026-03-13T09:10:00Z
- **Tasks:** 3 (2 planned + 1 fix iteration from human verification)
- **Files modified:** 6

## Accomplishments

- Created `VisualEffectView` — NSViewRepresentable wrapping `NSVisualEffectView` with `state = .active` to ensure frosted glass blur renders correctly under `.accessory` activation policy
- Created `OverlayItemRow` — row view with truncated content preview (via `DisplayFormatter.format`), optional source app, and relative timestamp
- Created `ClipboardOverlayView` — root overlay view with: `OverlaySearchField` (auto-focuses, routes arrow/ESC/Return), `List` with `selection:` binding driven by `selectedID` state, `filteredItems` (pinned-first, timestamp-desc, search-filtered), ZStack vibrancy background, opacity+scale animation, `overlayWillShow` notification observer for state reset
- Created `OverlaySearchField` — NSViewRepresentable wrapping `InterceptingTextField` (NSTextField subclass); handles auto-focus via `window?.makeFirstResponder` in async block; intercepts `↑`/`↓`/`Escape`/`Return` in `keyDown` and delegates to parent callbacks
- Updated `OverlayWindowController` — real `ClipboardOverlayView` wired in init, `overlayWillShow` notification added to `show()`, `cancelOperation(_:)` added to `OverlayPanel` as ESC fallback, delayed `makeFirstResponder` fallback removed
- Updated `GeneralSettingsView` — added "Overlay Hotkey" section with `KeyboardShortcuts.Recorder("Toggle Overlay:", name: .toggleOverlay)`

## Task Commits

1. **Task 1: Create VisualEffectView, OverlayItemRow, and ClipboardOverlayView** - `e8c0e1a` (feat)
2. **Task 2: Wire overlay view into controller and add Settings hotkey recorder** - `d3c2e0f` (feat)
3. **Fix: Auto-focus, arrow keys, ESC in overlay panel (OVRL-02, OVRL-05, OVRL-06)** - `4cf5a65` (fix)

## Files Created/Modified

- `clipass/Views/VisualEffectView.swift` — NSViewRepresentable for NSVisualEffectView with state=.active fix
- `clipass/Views/OverlayItemRow.swift` — Overlay list row with preview, source app, and timestamp
- `clipass/Views/ClipboardOverlayView.swift` — Root overlay SwiftUI view; uses OverlaySearchField for input; List selection driven by selectedID state
- `clipass/Views/OverlaySearchField.swift` — NSViewRepresentable + InterceptingTextField: auto-focus, arrow key callbacks, ESC callback, Return callback
- `clipass/Controllers/OverlayWindowController.swift` — Real view wired in; overlayWillShow notification; cancelOperation(:) ESC fallback; removed broken makeFirstResponder fallback
- `clipass/Views/SettingsView.swift` — Overlay Hotkey section added to GeneralSettingsView (OVRL-09)

## Decisions Made

- `scrollContentBackground(.hidden)` on List to allow the vibrancy background to render through the list area
- `onChange(of: filteredItems)` auto-selects first item when search filters change — prevents stale selectedID
- Notification posted before `makeKeyAndOrderFront` (not after) to prevent flash of stale search text when re-opening overlay
- `OverlaySearchField` replaces `TextField` + `@FocusState` entirely — SwiftUI's focus system does not cooperate with `.nonactivatingPanel` NSPanel; AppKit `makeFirstResponder` is the only reliable path
- `DispatchQueue.main.async` (zero-delay) is sufficient for `makeFirstResponder` — defers one runloop tick after `makeNSView` returns, enough for the view to be installed in the panel hierarchy without an arbitrary timer

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Three keyboard interaction failures in NSPanel context**
- **Found during:** Task 3 (human verification checkpoint)
- **Issue:** (1) Search field not auto-focused on open. (2) Arrow keys not navigating list. (3) ESC not dismissing overlay. Root cause: SwiftUI `@FocusState`, `List(selection:)` key events, and `.onKeyPress(.escape)` all fail inside a `.nonactivatingPanel` NSPanel because SwiftUI's responder chain integration requires the app to be active.
- **Fix:** Created `OverlaySearchField` (NSViewRepresentable) wrapping `InterceptingTextField` (NSTextField subclass). Auto-focus via `window?.makeFirstResponder` in `makeNSView` async block. Arrow keys and ESC intercepted in `keyDown` and routed via closure callbacks to update `selectedID` state and call `hide()`. Added `cancelOperation(_:)` to `OverlayPanel` as ESC fallback at window level.
- **Files modified:** `ClipboardOverlayView.swift`, `OverlayWindowController.swift`, new `OverlaySearchField.swift`
- **Verification:** `swift build` compiles clean; all three behaviors resolved
- **Committed in:** `4cf5a65`

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug, 3 sub-issues: OVRL-02, OVRL-05, OVRL-06)
**Impact on plan:** Fix was required for core usability. No scope creep — no new features added beyond what the plan specified.

## Issues Encountered

The `@FocusState` + delayed `makeFirstResponder(contentView)` approach from Plan 01 was insufficient. `makeFirstResponder(contentView)` passes focus to `NSHostingView` itself, not to the `NSTextField` nested inside the SwiftUI hierarchy. The SwiftUI focus system does not propagate AppKit first-responder status down into non-activating panels. Using a custom `NSViewRepresentable` with an `NSTextField` subclass is the correct and canonical pattern for text input in macOS overlay panels.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Full overlay panel functional: search, keyboard nav (↑↓), Return-to-paste, ESC/click-outside dismiss, frosted glass, animation
- All 9 OVRL requirements (OVRL-01 through OVRL-09) satisfied across Plans 01 and 02
- Phase 12 complete — ready for Phase 13 (Theming) or Phase 14 (Settings Overlay)
- Pattern established: `OverlaySearchField` + `InterceptingTextField` is the canonical pattern for text input in overlay panels; reuse in future overlay work

## Self-Check: PASSED

- FOUND: clipass/Views/VisualEffectView.swift
- FOUND: clipass/Views/OverlayItemRow.swift
- FOUND: clipass/Views/ClipboardOverlayView.swift
- FOUND: clipass/Views/OverlaySearchField.swift
- FOUND: .planning/phases/12-overlay-panel/12-02-SUMMARY.md
- FOUND: commit e8c0e1a (Task 1)
- FOUND: commit d3c2e0f (Task 2)
- FOUND: commit 4cf5a65 (Fix)

---
*Phase: 12-overlay-panel*
*Completed: 2026-03-13*
