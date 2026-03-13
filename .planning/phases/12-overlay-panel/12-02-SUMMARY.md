---
phase: 12-overlay-panel
plan: "02"
subsystem: ui
tags: [SwiftUI, NSVisualEffectView, NSPanel, vibrancy, overlay, search, keyboard-navigation, KeyboardShortcuts, animation]

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
    - "onKeyPress(.return)/.onKeyPress(.escape) on List for Return-to-paste and ESC-dismiss"
    - "@FocusState on search TextField with onAppear + notification observer for focus reset"
    - ".transition(.opacity.combined(with: .scale(scale: 0.95))) + .animation(.easeOut(duration: 0.15)) for show animation"
    - "ZStack with VisualEffectView() background + .clipShape(RoundedRectangle(cornerRadius: 12))"

key-files:
  created:
    - clipass/Views/VisualEffectView.swift
    - clipass/Views/OverlayItemRow.swift
    - clipass/Views/ClipboardOverlayView.swift
  modified:
    - clipass/Controllers/OverlayWindowController.swift
    - clipass/Views/SettingsView.swift

key-decisions:
  - "scrollContentBackground(.hidden) + listStyle(.plain) on List to allow vibrancy background to show through"
  - "onChange(of: filteredItems) auto-selects first item when list changes — prevents selectedID pointing to an item no longer in results"
  - "overlayWillShow notification used (not overlayDidShow) to reset state before view becomes visible, preventing flash of stale content"
  - "OverlayItemRow uses DisplayFormatter.format with empty patterns [] — no redaction needed in overlay (speed over privacy in hotkey context)"

# Metrics
duration: ~5min
completed: 2026-03-13
---

# Phase 12 Plan 02: Overlay UI Views Summary

**SwiftUI overlay view with frosted glass vibrancy, real-time search, keyboard navigation (arrow keys + Return-to-paste + ESC-dismiss), smooth opacity+scale animation, and Settings hotkey recorder**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-13T08:53:07Z
- **Completed:** 2026-03-13T08:58:00Z
- **Tasks:** 2 of 3 complete (Task 3 is checkpoint:human-verify — awaiting user verification)
- **Files modified:** 5

## Accomplishments

- Created `VisualEffectView` — NSViewRepresentable wrapping `NSVisualEffectView` with `state = .active` to ensure frosted glass blur renders correctly under `.accessory` activation policy
- Created `OverlayItemRow` — row view with truncated content preview (via `DisplayFormatter.format`), optional source app, and relative timestamp
- Created `ClipboardOverlayView` — root overlay view with: search field (`@FocusState`), `List` with selection binding, `filteredItems` (pinned-first, timestamp-desc, search-filtered), `onKeyPress(.return)` → `pasteAndHide`, `onKeyPress(.escape)` → `hide()`, ZStack vibrancy background, opacity+scale animation, `overlayWillShow` notification observer for state reset
- Updated `OverlayWindowController.init()` — replaced `Text("Overlay placeholder")` with `ClipboardOverlayView().modelContext(AppServices.shared.modelContainer.mainContext)`
- Updated `OverlayWindowController.show()` — posts `overlayWillShow` notification BEFORE `makeKeyAndOrderFront` so the view resets state before becoming visible
- Updated `GeneralSettingsView` in `SettingsView.swift` — added "Overlay Hotkey" section with `KeyboardShortcuts.Recorder("Toggle Overlay:", name: .toggleOverlay)` after existing Hotkey section

## Task Commits

1. **Task 1: Create VisualEffectView, OverlayItemRow, and ClipboardOverlayView** - `e8c0e1a` (feat)
2. **Task 2: Wire overlay view into controller and add Settings hotkey recorder** - `d3c2e0f` (feat)

## Files Created/Modified

- `clipass/Views/VisualEffectView.swift` — NSViewRepresentable for NSVisualEffectView with state=.active fix
- `clipass/Views/OverlayItemRow.swift` — Overlay list row with preview, source app, and timestamp
- `clipass/Views/ClipboardOverlayView.swift` — Root overlay SwiftUI view with all OVRL-05 through OVRL-08 behaviors
- `clipass/Controllers/OverlayWindowController.swift` — Real view wired in; overlayWillShow notification added to show()
- `clipass/Views/SettingsView.swift` — Overlay Hotkey section added to GeneralSettingsView (OVRL-09)

## Decisions Made

- `scrollContentBackground(.hidden)` on List to allow the vibrancy background to render through the list area
- `onChange(of: filteredItems)` auto-selects first item when search filters change — prevents stale selectedID
- Notification posted before `makeKeyAndOrderFront` (not after) to prevent flash of stale search text when re-opening overlay

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

Pre-existing deprecation warning for `activate(options: .activateIgnoringOtherApps)` in `OverlayWindowController.restoreFocus()` — same as noted in Plan 01 summary. Not a blocker.

## Pending

Task 3 (checkpoint:human-verify) requires manual testing of all 9 OVRL requirements. See verification checklist in the plan.

## Self-Check: PASSED

- FOUND: clipass/Views/VisualEffectView.swift
- FOUND: clipass/Views/OverlayItemRow.swift
- FOUND: clipass/Views/ClipboardOverlayView.swift
- FOUND: .planning/phases/12-overlay-panel/12-02-SUMMARY.md
- FOUND: commit e8c0e1a (Task 1)
- FOUND: commit d3c2e0f (Task 2)

---
*Phase: 12-overlay-panel*
*Completed: 2026-03-13*
