---
phase: 13-theme-system
plan: "01"
subsystem: theme-system
tags: [theme, model, observable, appkit, swiftui, environment]
dependency_graph:
  requires: []
  provides: [Theme.swift, ThemeManager.swift, VisualEffectView-BackgroundMode, themeManager-environment-injection]
  affects: [clipass/Views/ClipboardOverlayView.swift, clipass/Views/OverlayItemRow.swift]
tech_stack:
  added: [Observation framework (@Observable)]
  patterns: [ThemeManager-singleton-via-AppServices, SwiftUI-environment-injection-into-NSHostingView, BackgroundMode-driven-VisualEffectView]
key_files:
  created:
    - clipass/Models/Theme.swift
    - clipass/Services/ThemeManager.swift
  modified:
    - clipass/Views/VisualEffectView.swift
    - clipass/Controllers/OverlayWindowController.swift
    - clipass/clipassApp.swift
decisions:
  - "Dark and Nord use solid backgrounds — opaque palettes don't benefit from vibrancy"
  - "Light theme forced to .aqua appearance via forceAppearance to work correctly in Dark Mode system setting"
  - "Midnight uses tintedVibrancy with 0.6 opacity purple tint over forced darkAqua — delivers distinct mood from Dark theme"
  - "System theme uses tintedVibrancy at 0.15 opacity with Color.accentColor — subtle personalisation without manual selection"
  - "forceAppearance set in updateNSView not makeNSView — NSAppearance resolution requires view to be in hierarchy (Pitfall 1)"
  - "@AppStorage stores String rawValue not ThemeID directly — avoids Codable infinite-recursion trap (Pitfall 6)"
  - "ThemeManager.init reads UserDefaults.standard directly rather than via @AppStorage to get persisted value before @AppStorage property wrapper syncs"
metrics:
  duration: "~2 min"
  completed: "2026-03-16"
  tasks_completed: 2
  files_created: 2
  files_modified: 3
---

# Phase 13 Plan 01: Theme Model and Environment Infrastructure Summary

**One-liner:** Theme data model with 5 distinct palettes and @Observable ThemeManager injected via .environment() into both the overlay NSHostingView and Settings window.

## What Was Built

### Task 1: Theme.swift + ThemeManager.swift

`clipass/Models/Theme.swift` contains:
- `Color(hex:)` initializer using Scanner + UInt64 approach
- 13 Nord palette constants (`nordPolarNight0-3`, `nordSnowStorm4-6`, `nordFrost7-10`, `nordAurora11/14/15`)
- `BackgroundMode` enum with `.vibrancy(material:)`, `.tintedVibrancy(material:tint:opacity:)`, `.solid`
- `DividerStyle` enum with `.standard`, `.thick`, `.none`
- `ThemeID: String, CaseIterable` with 5 cases: `system`, `dark`, `light`, `midnight`, `nord`
- `Theme` struct with 18 properties including `forceAppearance: NSAppearance?`
- `Theme.themes` dictionary with complete definitions for all 5 themes

`clipass/Services/ThemeManager.swift` contains:
- `@Observable final class ThemeManager`
- `var current: Theme` — the active theme read by all overlay views
- `@ObservationIgnored @AppStorage("selectedThemeID") private var storedThemeID: String`
- `var selectedID: ThemeID` — computed from stored string
- `init()` reads from `UserDefaults.standard` directly to get persisted value at startup
- `func select(_ id: ThemeID)` — updates both storage and current simultaneously

### Task 2: VisualEffectView + Environment Wiring

`clipass/Views/VisualEffectView.swift` replaced:
- Old: `material: NSVisualEffectView.Material`, `blendingMode: NSVisualEffectView.BlendingMode` init
- New: `backgroundMode: BackgroundMode = .vibrancy(material: .hudWindow)`, `forceAppearance: NSAppearance? = nil`, `solidColor: NSColor? = nil`
- Three rendering paths: vibrancy (NSVisualEffectView), tintedVibrancy (NSView container with vibrant sublayer + tint overlay), solid (plain NSView)
- `state = .active` re-applied in `updateNSView` on every material update (Pitfall 5)
- `forceAppearance` applied in `updateNSView` (not `makeNSView`) to respect NSAppearance hierarchy resolution timing (Pitfall 1)

`clipass/Controllers/OverlayWindowController.swift`: added `.environment(AppServices.shared.themeManager)` to overlay view injection chain.

`clipass/clipassApp.swift`:
- Added `let themeManager = ThemeManager()` to `AppServices`
- Added `.environment(services.themeManager)` to Settings `Window` scene

## Theme Palette Summary

| Theme | Background Mode | Personality |
|-------|----------------|-------------|
| System | tintedVibrancy (accentColor, 0.15) | Adapts to macOS; personalised with user's accent color |
| Dark | solid #1e1e1e | Clean dark, blue accent, no vibrancy |
| Light | vibrancy .hudWindow (forced .aqua) | Always light regardless of system mode |
| Midnight | tintedVibrancy (purple, 0.6, forced .darkAqua) | Deep purple mood, sharper corners, thick dividers |
| Nord | solid nordPolarNight0 | Official Nord hex palette, softer corners |

## Deviations from Plan

None — plan executed exactly as written.

The one minor implementation detail: `ThemeManager.init()` reads from `UserDefaults.standard` directly (instead of reading `storedThemeID` which is the `@AppStorage` property) because `@AppStorage` property wrappers may not be fully initialized before `init()` body runs. This matches the research pattern and avoids a potential nil/default value on first launch.

## Self-Check

Build passes: `swift build` → `Build complete! (0.13s)` — no warnings, no errors.
