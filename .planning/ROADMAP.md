# Roadmap: clipass

## Milestones

- ✅ **v1.0 MVP** - Phases 1-5 (shipped 2026-02-05)
- ✅ **v1.1 More Control** - Phases 6-11 (shipped 2026-03-13)
- ✅ **v2.0 Overlay UI & Theming** - Phases 12-14 (shipped 2026-03-19)
- 🚧 **v2.1 Developer Power Tools** - Phases 15-19 (in progress)

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

<details>
<summary>✅ v2.0 Overlay UI & Theming (Phases 12-14) - SHIPPED 2026-03-19</summary>

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
- [x] 13-01-PLAN.md — Theme model and infrastructure (Theme struct, ThemeManager @Observable, 5 theme definitions, VisualEffectView BackgroundMode, environment injection)
- [x] 13-02-PLAN.md — Theme consumption and settings UI (overlay view theming, AppearanceSettingsView with mini mockup preview cards, Appearance settings tab)

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
- [x] 14-01-PLAN.md — Inline editor (EditorTextView NSViewRepresentable, InlineEditorPanel, pencil icon on rows, edit state management, ESC conflict resolution, SwiftData round-trip)

</details>

### v2.1 Developer Power Tools (In Progress)

**Milestone Goal:** Make clipass a programmable clipboard platform — tags for organization, a CLI binary for terminal workflows, pub/sub event streaming for automation, action chains for multi-step transforms, and small QoL improvements.

## Phase Details

### Phase 15: Tags
**Goal**: Users can organize clipboard items with colored tags and filter history by tag in the overlay
**Depends on**: Phase 14
**Requirements**: TAG-01, TAG-02, TAG-03, TAG-04, TAG-05
**Success Criteria** (what must be TRUE):
  1. User can add and remove tags on a clipboard item via the overlay editor or context menu
  2. User can type `tag:work` in the overlay search field and see only items tagged `work`
  3. Tags display as colored badges on overlay rows
  4. User can rename, delete, and set a color for any tag in Settings > Tags
**Plans**: 2 plans

Plans:
- [ ] 15-01-PLAN.md — Tag data model (SwiftData Tag @Model, many-to-many with ClipboardItem, ModelContainer registration)
- [ ] 15-02-PLAN.md — Tag UI (TagBadgeView, context menu tag assignment, overlay search tag: filter, Settings Tags tab)

### Phase 16: CLI Foundation
**Goal**: Users can interact with clipboard history from the terminal via a `clipass` CLI binary
**Depends on**: Phase 15
**Requirements**: CLI-01, CLI-02, CLI-03, CLI-06, CLI-07
**Success Criteria** (what must be TRUE):
  1. User can run `clipass list` in the terminal and see recent clipboard items in readable columns
  2. User can run `clipass copy` (or pipe text to it) and have that text added to clipboard history
  3. User can run `clipass paste` to print the most recent item, and `clipass delete`/`clipass clear` to remove items
  4. User can run `clipass search "query"` to find items matching a term
  5. Any command accepts `--json` to produce machine-readable output suitable for `jq` pipelines
**Plans**: TBD

Plans:
- [ ] 16-01: Socket server in-app (Unix domain socket, length-prefix framing, command dispatch to @MainActor SwiftData context, ClipassShared library target)
- [ ] 16-02: CLI binary and core commands (clipass-cli executableTarget, list/get/copy/paste/delete/clear/search/status, --json flag, item addressing by index or UUID)

### Phase 17: Tag CLI + Pub/Sub
**Goal**: Users can manage tags from the terminal and stream clipboard events to stdout for scripting
**Depends on**: Phase 16
**Requirements**: CLI-04, PUBSUB-01, PUBSUB-02, PUBSUB-03
**Success Criteria** (what must be TRUE):
  1. User can run `clipass tag add 3 work` to tag the 3rd most recent item and `clipass tag list` to see all tags with counts
  2. App broadcasts clipboard events (copy, delete, tag changes, pause/resume, clear) over the Unix socket
  3. User can run `clipass listen` and see a live stream of newline-delimited JSON events in the terminal
  4. User can filter the event stream with `--event copy`, `--tag work`, or `--source-app Terminal` flags
**Plans**: TBD

Plans:
- [ ] 17-01: Tag CLI commands (clipass tag add/remove/list, clipass list --tag filter, socket protocol for tag operations)
- [ ] 17-02: Pub/sub event streaming (app-side event broadcaster, subscribe message handling, filter evaluation, clipass listen command)

### Phase 18: Action Chains
**Goal**: Users can define multi-step transform pipelines, apply them from the overlay context menu, and run them from the terminal
**Depends on**: Phase 17
**Requirements**: CHAIN-01, CHAIN-02, CHAIN-03, CLI-05
**Success Criteria** (what must be TRUE):
  1. User can open Settings > Chains and create a named pipeline with multiple ordered steps (trim, case, replace, script, existing transform)
  2. User can right-click a clipboard item in the overlay and choose "Apply Chain" to run a chain on that item's content
  3. User can pipe text through a chain from the terminal with `clipass chain <name>` or `clipass transform <name>`
  4. Chains containing `script` steps display a warning indicator in Settings
**Plans**: TBD

Plans:
- [ ] 18-01: Action chain model (ActionChain + ChainStep SwiftData/Codable, step execution engine, built-in step types: trim/case/replace/script/transform)
- [ ] 18-02: Chain UI + CLI (Settings Chains tab with pipeline builder, overlay "Apply Chain" context menu, clipass chain and clipass transform CLI commands)

### Phase 19: QoL
**Goal**: Users can append to the last clipboard item, pause monitoring, and hide the menu bar icon
**Depends on**: Phase 15 (tags for append inheritance); Phase 17 (pub/sub for pause/resume events)
**Requirements**: QOL-01, QOL-02, QOL-03
**Success Criteria** (what must be TRUE):
  1. User can trigger a global hotkey (configurable) to append the current clipboard content to the most recent history item instead of creating a new entry
  2. User can pause clipboard monitoring from the menu bar or via `clipass pause` — the menu bar icon dims and no new items are recorded until resumed
  3. User can toggle "Show menu bar icon" in Settings > General to hide the icon and access clipass solely through the overlay shortcut or CLI
**Plans**: TBD

Plans:
- [ ] 19-01: Copy-append (appendPending flag on ClipboardMonitor, configurable hotkey via KeyboardShortcuts, CLI --append/-a flag, tag inheritance, overlay flash feedback)
- [ ] 19-02: Pause/resume + hide menu bar (isPaused state, dimmed icon, UserDefaults persistence, CLI pause/resume, pub/sub events, Settings toggle with overlay-shortcut guard)

## Progress

**Execution Order:**
Phases execute in numeric order: 15 → 16 → 17 → 18 → 19

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
| 13. Theme System | v2.0 | 2/2 | Complete | 2026-03-17 |
| 14. Inline Editor | v2.0 | 1/1 | Complete | 2026-03-19 |
| 15. Tags | 1/2 | In Progress|  | - |
| 16. CLI Foundation | v2.1 | 0/2 | Not started | - |
| 17. Tag CLI + Pub/Sub | v2.1 | 0/2 | Not started | - |
| 18. Action Chains | v2.1 | 0/2 | Not started | - |
| 19. QoL | v2.1 | 0/2 | Not started | - |
