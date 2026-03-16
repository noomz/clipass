# Phase 13: Theme System - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can select a theme in Settings that styles the overlay panel and persists across restarts. Ships with 5 options: System (auto), Dark, Light, Midnight, Nord. Theme applies to overlay only — menu bar popup retains existing style.

</domain>

<decisions>
## Implementation Decisions

### Theme palette & identity
- Each theme has a strong, distinct personality — not subtle variations
- 5 options total: System (follows macOS light/dark) + 4 named themes (Dark, Light, Midnight, Nord)
- System is the default theme
- Nord uses the official Nord palette (nordtheme.com) hex values — Polar Night, Snow Storm, Frost, Aurora
- Midnight has a purple/violet-tinted dark aesthetic — distinct from Dark theme via hue, not just depth
- Dark and Light are independent fixed themes; System handles the auto-switching role

### Themed surfaces — full styling
- All overlay elements are themed: background, text colors, selection highlight, accent color
- Search field fully themed: background, text color, placeholder color
- Dividers, bottom bar text, and item count all follow theme colors — no system colors leak through
- Per-theme corner radius (e.g., Nord softer, Midnight sharper)
- Per-theme typography: font weight and size can vary
- Per-theme spacing and divider style — each theme can feel structurally different

### Theme picker UX
- New "Appearance" tab in Settings (7th tab)
- Mini overlay mockups as preview cards — each shows a miniature overlay with fake clipboard items
- Vertical list layout — stacked full-width cards, scrollable
- Instant apply — selecting a theme immediately applies it everywhere, no separate "Apply" button
- Selected theme shows a checkmark or highlight indicator

### Vibrancy interaction
- Theme struct includes explicit `backgroundMode` flag: `.vibrancy`, `.solid`, or `.tintedVibrancy(opacity)`
- Each theme declares its own background strategy — not inferred from alpha
- System theme uses vibrancy tinted with the user's macOS accent color
- Dark/Light themes: Claude decides vibrancy vs solid based on palette
- Midnight/Nord themes: Claude decides based on what serves each palette best

### Claude's Discretion
- Tint strength per theme (strong vs subtle) for vibrancy-enabled themes
- Dark and Light vibrancy vs solid decision
- Midnight and Nord vibrancy vs solid decision
- Exact font sizes and weights per theme
- Exact spacing and divider styling per theme
- Exact corner radius values per theme
- Mini mockup fake data content
- Theme struct property names and architecture

</decisions>

<specifics>
## Specific Ideas

- Midnight should feel like a different mood from Dark — the purple/violet undertone is the key differentiator
- Nord fans should recognize the palette immediately (official hex values)
- System theme with macOS accent color tint makes the default feel personalised without manual theme choice
- Mini overlay mockups in the picker should look like real miniature overlays (search bar, item rows, selection highlight)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VisualEffectView` (NSViewRepresentable): Already wraps NSVisualEffectView — will need to accept theme parameters for material/tint
- `OverlayItemRow`: Has `isSelected` highlight via `Color.accentColor` — needs to read theme colors instead
- `OverlaySearchField` (NSViewRepresentable): Borderless NSTextField — will need theme-aware background/text colors via AppKit properties
- `ClipboardOverlayView`: Root overlay view — theme injection point via Environment

### Established Patterns
- `@AppStorage` used for all persistent settings (maxHistoryItems, autoCleanupDays, hotkeys)
- Settings uses sidebarAdaptable TabView (macOS 15+) with tabItem fallback (macOS 14)
- SwiftUI Environment used for modelContext injection — same pattern works for theme
- OverlayWindowController singleton manages panel lifecycle

### Integration Points
- `SettingsView`: Add 7th "Appearance" tab for theme picker
- `ClipboardOverlayView`: Inject theme via Environment, replace hardcoded colors
- `OverlayItemRow`: Replace `Color.accentColor` and `Color.primary` with theme properties
- `VisualEffectView`: Accept theme background mode parameter
- `OverlaySearchField`: Pass theme colors to NSTextField properties in updateNSView

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-theme-system*
*Context gathered: 2026-03-16*
