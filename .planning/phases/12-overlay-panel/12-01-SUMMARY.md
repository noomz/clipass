---
phase: 12-overlay-panel
plan: "01"
subsystem: ui
tags: [NSPanel, SwiftUI, NSHostingView, KeyboardShortcuts, AppKit, overlay, focus-management]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: ClipboardItem SwiftData model and AppServices singleton used for modelContainer injection
  - phase: 11-context-actions
    provides: Final clipassApp.swift structure with AppServices.initialize() pattern this plan extends
provides:
  - OverlayPanel NSPanel subclass with non-activating floating configuration
  - OverlayWindowController singleton with show/hide/toggle/pasteAndHide/setContentView
  - KeyboardShortcuts.Name.toggleOverlay shortcut definition
  - toggleOverlay onKeyUp handler in AppServices.initialize()
affects: [12-overlay-ui, 13-theming, 14-settings-overlay]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSPanel subclass with .nonactivatingPanel in init() for non-activating floating panel"
    - "canBecomeKey/canBecomeMain overrides = true to allow keyboard input without app activation"
    - "resignKey() timing guard (shownAt + 0.3s) to prevent flash-close on panel init"
    - "NSWorkspace.shared.frontmostApplication captured before makeKeyAndOrderFront — restored on dismiss"
    - "DispatchQueue.main.asyncAfter(0.1) fallback for makeFirstResponder after @FocusState settlement"
    - "NotificationCenter.overlayDidResignKey for controller-to-panel dismiss communication"
    - "Force-init singleton at app launch for instant first-show response"

key-files:
  created:
    - clipass/Controllers/OverlayWindowController.swift
  modified:
    - clipass/clipassApp.swift

key-decisions:
  - "NSPanel init styleMask set in super.init() call — not modified post-init (nonactivatingPanel bit does not update kCGSPreventsActivationTagBit correctly when changed after init)"
  - "No default hotkey for toggleOverlay — user configures in Settings (Plan 12-03)"
  - "toggleOverlay handler omits NSApp.activate() — opposite of toggleClipboard which requires activation"
  - "resignKey timing guard set to 0.3s (slightly above research recommendation of 0.2s) for extra safety margin"
  - "setContentView<V>() generic injection method allows Plan 02 to replace placeholder without accessing panel directly"

patterns-established:
  - "OverlayWindowController.setContentView<V>(_:) is the API surface Plan 02 uses to inject ClipboardOverlayView"
  - "pasteAndHide(content:) is the API surface overlay item rows call on Return key press"
  - "Controllers/ directory established for AppKit window controller singletons"

requirements-completed: [OVRL-01, OVRL-02, OVRL-03, OVRL-04]

# Metrics
duration: 2min
completed: 2026-03-13
---

# Phase 12 Plan 01: Overlay Panel Foundation Summary

**NSPanel subclass (OverlayWindowController) with non-activating floating behavior, hotkey-driven toggle, ESC/click-outside dismissal, and previous-app focus restoration**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-13T08:49:11Z
- **Completed:** 2026-03-13T08:51:33Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `OverlayPanel` NSPanel subclass with `.nonactivatingPanel` style mask (must be in init), floating level, all-spaces/fullscreen behaviors, hidden titlebar, and `canBecomeKey`/`canBecomeMain` overrides
- Created `OverlayWindowController` singleton with `show()` (captures previousApp, centers on mouse screen, timing guard), `hide()` (restores focus), `toggle()`, `pasteAndHide()`, and `setContentView<V>()` for Plan 02 injection
- Wired `KeyboardShortcuts.Name.toggleOverlay` shortcut and `onKeyUp` handler in `AppServices.initialize()` — no `NSApp.activate()` call, preserving non-activating behavior
- Project builds clean with no errors

## Task Commits

1. **Task 1: Create OverlayPanel and OverlayWindowController** - `8509abc` (feat)
2. **Task 2: Register overlay hotkey and wire toggle** - `1863d49` (feat)

## Files Created/Modified
- `clipass/Controllers/OverlayWindowController.swift` - OverlayPanel NSPanel subclass + OverlayWindowController singleton (show/hide/toggle/pasteAndHide/setContentView)
- `clipass/clipassApp.swift` - Added toggleOverlay shortcut name, onKeyUp handler, and singleton pre-init

## Decisions Made
- `resignKey()` timing guard set to 0.3s (research recommendation was 0.2s — slightly extended for safety margin on slower machines)
- No default hotkey assigned to `toggleOverlay` — follows research recommendation that users should configure this explicitly to avoid conflicts
- `setContentView<V: View>(_ view: V)` generic method chosen over requiring callers to construct `NSHostingView` themselves — cleaner API surface for Plan 02

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

One deprecation warning for `activate(options: .activateIgnoringOtherApps)` (deprecated macOS 14). This is the established pattern in the codebase (same usage already in the existing toggleClipboard handler) and is the correct API for focus restoration. The warning is pre-existing and does not affect functionality.

## User Setup Required

None — no external service configuration required. Overlay hotkey defaults to unset; user configures in Settings (Plan 12-03 adds the Recorder UI).

## Next Phase Readiness
- `OverlayWindowController.setContentView<V>()` is ready for Plan 02 to inject `ClipboardOverlayView`
- `OverlayWindowController.pasteAndHide()` is ready for Plan 02's Return key handler
- Panel infrastructure complete; Plan 02 can focus purely on SwiftUI overlay UI content
- Concern from STATE.md still applies: validate `@FocusState` reliability in NSPanel-hosted SwiftUI — the `makeFirstResponder` fallback is implemented and ready

---
*Phase: 12-overlay-panel*
*Completed: 2026-03-13*
