# Roadmap: clipass

## Milestones

- ✅ **v1.0 MVP** - Phases 1-5 (shipped 2026-02-05)
- ✅ **v1.1 More Control** - Phases 6-11 (shipped 2026-03-13)
- 🚧 **v2.0 Overlay UI & Theming** - Phases 12-14 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) - SHIPPED 2026-02-05</summary>

### Phase 1: Foundation
**Goal**: Project scaffolding, clipboard monitoring, and persistent history
**Plans**: 2 plans

Plans:
- [x] 01-01: Project setup and clipboard monitor
- [x] 01-02: SwiftData persistence and history model

### Phase 2: Menu Bar UI
**Goal**: Menu bar icon, popup UI, search, and global hotkey
**Plans**: 2 plans

Plans:
- [x] 02-01: MenuBarExtra popup with history list and search
- [x] 02-02: Global hotkey integration (KeyboardShortcuts)

### Phase 3: Transform Engine
**Goal**: Rule-based regex transform system that auto-cleans clipboard content
**Plans**: 2 plans

Plans:
- [x] 03-01: Transform rule engine with regex patterns and defaults
- [x] 03-02: Auto-format on paste (trailing whitespace strip)

### Phase 4: Automation
**Goal**: External hooks and app-specific behavior triggers
**Plans**: 2 plans

Plans:
- [x] 04-01: External shell hook on clipboard change
- [x] 04-02: App-specific behavior based on source app

### Phase 5: Settings
**Goal**: Dedicated Settings window with tabbed configuration
**Plans**: 1 plan

Plans:
- [x] 05-01: Settings window with General, Transforms, Automation tabs

</details>

<details>
<summary>✅ v1.1 More Control (Phases 6-11) - SHIPPED 2026-03-13</summary>

### Phase 6: Filtering
**Goal**: App and content ignore patterns with regex support
**Plans**: 1 plan

Plans:
- [x] 06-01: Configurable ignored apps and content patterns

### Phase 7: Display
**Goal**: Display formatting with sensitive content redaction and preview controls
**Plans**: 1 plan

Plans:
- [x] 07-01: Redaction patterns, preview truncation, invisible char cleanup

### Phase 8: User Controls
**Goal**: Launch at Login, max history, hotkey customization, auto-cleanup
**Plans**: 1 plan

Plans:
- [x] 08-01: General settings expansion (login, history limits, cleanup, hotkey)

### Phase 9: Settings Navigation
**Goal**: macOS-native Settings with sidebarAdaptable tab navigation
**Plans**: 1 plan

Plans:
- [x] 09-01: Settings redesign with sidebarAdaptable TabView

### Phase 10: (merged into Phase 11)
**Goal**: Merged — see Phase 11
**Plans**: 0 plans

### Phase 11: Smart Context Actions
**Goal**: Smart content-aware context menu, pin/unpin items, custom user-defined actions
**Plans**: 1 plan

Plans:
- [x] 11-01: ContentAnalyzer, pin/unpin, custom shell-command actions

</details>

### v2.0 Overlay UI & Theming (In Progress)

**Milestone Goal:** Raycast-style floating overlay panel, semantic theme system, and click-to-edit inline text editor.

## Phase Details

### Phase 12: Overlay Panel
**Goal**: Users can summon and use a floating overlay panel to browse and paste clipboard items via keyboard
**Depends on**: Phase 11 (v1.1 complete)
**Requirements**: OVRL-01, OVRL-02, OVRL-03, OVRL-04, OVRL-05, OVRL-06, OVRL-07, OVRL-08, OVRL-09
**Success Criteria** (what must be TRUE):
  1. User can summon and dismiss the overlay via a dedicated global hotkey (separate from menu bar shortcut)
  2. User can dismiss the overlay with ESC or by clicking outside — focus returns to the previously active app without disruption
  3. User can navigate clipboard items with arrow keys and paste the selected item with Return, without touching the mouse
  4. Search field receives focus automatically on open, and the overlay shows/hides with smooth animation and frosted glass background
  5. User can configure the overlay hotkey in Settings
**Plans**: 2 plans

Plans:
- [x] 12-01-PLAN.md — NSPanel foundation (OverlayPanel, OverlayWindowController, hotkey registration, show/hide/toggle, ESC/click-outside dismiss)
- [x] 12-02-PLAN.md — Overlay SwiftUI view (ClipboardOverlayView, search, keyboard nav, Return-to-paste, vibrancy, animation, Settings hotkey recorder)

### Phase 13: Theme System
**Goal**: Users can select a theme in Settings that styles the overlay and persists across restarts
**Depends on**: Phase 12
**Requirements**: THME-01, THME-02, THME-03, THME-04
**Success Criteria** (what must be TRUE):
  1. User can open Settings and see an Appearance tab with 5 theme options (System, Dark, Light, Midnight, Nord)
  2. User can select a theme and immediately see the overlay reflect the new colors without restarting
  3. The selected theme is still active after closing and reopening the app
  4. The theme picker shows a live preview of each theme before the user commits
**Plans**: 2 plans

Plans:
- [ ] 13-01-PLAN.md — Theme model and infrastructure (Theme struct, ThemeManager @Observable, 5 theme definitions, VisualEffectView BackgroundMode, environment injection)
- [ ] 13-02-PLAN.md — Theme consumption and settings UI (overlay view theming, AppearanceSettingsView with mini mockup preview cards, Appearance settings tab)

### Phase 14: Inline Editor
**Goal**: Users can edit a clipboard item directly in the overlay and have changes immediately reflected in the menu bar popup
**Depends on**: Phase 13
**Requirements**: EDIT-01, EDIT-02, EDIT-03, EDIT-04
**Success Criteria** (what must be TRUE):
  1. User can click a clipboard item in the overlay to enter an inline edit mode for that row
  2. User can modify the text and save — the updated content appears in the overlay list and the menu bar popup without restarting
  3. User can cancel editing with ESC and the row reverts to display mode without dismissing the overlay
  4. Saving an edit does not create a duplicate entry in clipboard history
**Plans**: 1 plan

Plans:
- [ ] 14-01-PLAN.md — Inline editor (EditorTextView NSViewRepresentable, InlineEditorPanel, pencil icon on rows, edit state management, ESC conflict resolution, SwiftData round-trip)

## Progress

**Execution Order:**
Phases execute in numeric order: 12 → 13 → 14

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 2/2 | Complete | 2026-02-05 |
| 2. Menu Bar UI | v1.0 | 2/2 | Complete | 2026-02-05 |
| 3. Transform Engine | v1.0 | 2/2 | Complete | 2026-02-05 |
| 4. Automation | v1.0 | 2/2 | Complete | 2026-02-05 |
| 5. Settings | v1.0 | 1/1 | Complete | 2026-02-05 |
| 6. Filtering | v1.1 | 1/1 | Complete | 2026-03-13 |
| 7. Display | v1.1 | 1/1 | Complete | 2026-03-13 |
| 8. User Controls | v1.1 | 1/1 | Complete | 2026-03-13 |
| 9. Settings Navigation | v1.1 | 1/1 | Complete | 2026-03-13 |
| 10. (merged) | v1.1 | 0/0 | Complete | 2026-03-13 |
| 11. Smart Context Actions | v1.1 | 1/1 | Complete | 2026-03-13 |
| 12. Overlay Panel | v2.0 | 2/2 | Complete | 2026-03-13 |
| 13. Theme System | 2/2 | Complete    | 2026-03-17 | - |
| 14. Inline Editor | 1/1 | Complete    | 2026-03-19 | - |
