---
phase: 13-theme-system
plan: "02"
subsystem: ui
tags: [swiftui, theming, nsviewrepresentable, appkit, macos]

# Dependency graph
requires:
  - phase: 13-01
    provides: Theme model, ThemeManager @Observable, VisualEffectView BackgroundMode, ThemeID enum

provides:
  - Theme-aware ClipboardOverlayView (background, dividers, bottom bar text via ThemeManager)
  - Theme-aware OverlayItemRow (selection highlight, text colors, corner radius, padding, font)
  - Theme-aware OverlaySearchField (text, placeholder, background colors via explicit theme param)
  - AppearanceSettingsView with 5 ThemePreviewCard mini mockup cards
  - MiniOverlayMockup renders miniature overlay layout per theme
  - SettingsView with 7th Appearance tab (paintbrush icon, macOS 15+ and legacy)

affects: [14-inline-editor, any future overlay views]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Environment(ThemeManager.self) for overlay views consuming theme from singleton"
    - "Explicit theme: Theme parameter on NSViewRepresentable (not @Environment — unreliable for NSView updates)"
    - "scaleEffect(0.5) + frame collapse pattern for mini mockup preview cards"
    - "@ViewBuilder themedDivider computed property for DividerStyle switch"

key-files:
  created:
    - clipass/Views/AppearanceSettingsView.swift
  modified:
    - clipass/Views/ClipboardOverlayView.swift
    - clipass/Views/OverlayItemRow.swift
    - clipass/Views/OverlaySearchField.swift
    - clipass/Views/SettingsView.swift

key-decisions:
  - "NSViewRepresentable receives theme as explicit parameter — @Environment is not reliable for NSView update cycles"
  - "MiniOverlayMockup uses solid Rectangle fill (not VisualEffectView) for vibrancy-free rendering at small scale"
  - "scaleEffect(0.5, anchor: .topLeading) + .frame(width: 240, height: 150) collapses layout after scaling (Research Pitfall 2)"
  - "Selected text color stays .white for all themes — itemBackground values are always sufficiently dark/saturated"
  - "Pin icon stays .orange (brand color, not themed)"

patterns-established:
  - "themedDivider @ViewBuilder: switch on theme.dividerStyle returning Rectangle/EmptyView"
  - "Theme convenience property: private var theme: Theme { themeManager.current }"

requirements-completed: [THME-01, THME-02, THME-03, THME-04]

# Metrics
duration: 10min
completed: 2026-03-16
---

# Phase 13 Plan 02: Theme Application & Appearance Settings Summary

**Theme colors wired to all overlay views via ThemeManager environment, plus Appearance settings tab with 5 mini-mockup preview cards for instant theme selection**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-16T05:10:00Z
- **Completed:** 2026-03-16T05:20:00Z
- **Tasks:** 2 of 3 completed (Task 3 is human verification checkpoint)
- **Files modified:** 5

## Accomplishments

- All overlay elements (background, dividers, text, search field, selection highlight, corner radii, padding, font) driven by `themeManager.current`
- `themedDivider` @ViewBuilder handles all three `DividerStyle` cases (standard/thick/none)
- `OverlaySearchField` applies theme text/placeholder/background colors in both `makeNSView` and `updateNSView` via explicit `theme: Theme` parameter
- `AppearanceSettingsView` shows 5 `ThemePreviewCard` cards with `MiniOverlayMockup` rendered at 480x300 and scaled to 240x150
- Appearance tab added as 7th tab in both macOS 15+ `sidebarAdaptable` and legacy `tabItem` TabView paths
- `swift build` clean with no new errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Apply theme to overlay views and search field** - `28712c7` (feat)
2. **Task 2: Create AppearanceSettingsView with mini mockup preview cards** - `14ff188` (feat)

_Task 3 is a human-verify checkpoint — awaiting user confirmation._

## Files Created/Modified

- `clipass/Views/ClipboardOverlayView.swift` - Added @Environment(ThemeManager.self), theme convenience property, themedDivider, theme-aware VisualEffectView/clipShape/bottom bar
- `clipass/Views/OverlayItemRow.swift` - Added @Environment(ThemeManager.self), replaced all hardcoded colors/radius/padding/font with theme values
- `clipass/Views/OverlaySearchField.swift` - Added explicit theme: Theme parameter, applyTheme() helper called in makeNSView and updateNSView
- `clipass/Views/AppearanceSettingsView.swift` - Created MiniOverlayMockup, ThemePreviewCard, AppearanceSettingsView
- `clipass/Views/SettingsView.swift` - Added 7th Appearance tab in both modern and legacy TabView

## Decisions Made

- `NSViewRepresentable` receives `theme` as an explicit parameter rather than via `@Environment` — `@Environment` values are not reliably updated during `updateNSView` cycles in NSViewRepresentable wrappers.
- `MiniOverlayMockup` uses a solid `Rectangle` fill for the background instead of `VisualEffectView` — `NSVisualEffectView` does not render correctly at reduced scale inside SwiftUI previews/settings panels.
- `scaleEffect(0.5, anchor: .topLeading)` + `.frame(width: 240, height: 150)` collapses the layout space after scaling (Research Pitfall 2 pattern).

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Complete theme system ready; all 5 themes (System, Dark, Light, Midnight, Nord) render in overlay
- Appearance tab is the 7th tab in Settings with instant-apply and persistence
- Ready for Phase 14 inline editor if verification passes

---
*Phase: 13-theme-system*
*Completed: 2026-03-16*
