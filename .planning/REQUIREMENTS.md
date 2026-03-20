# Requirements: clipass

**Defined:** 2026-03-13
**Core Value:** Smart transforms — auto-cleaning and formatting clipboard content before paste

## v2.1 Requirements

Requirements for v2.1 Developer Power Tools. Each maps to roadmap phases.

### Tags

- [x] **TAG-01**: User can add tags to clipboard items
- [x] **TAG-02**: User can remove tags from clipboard items
- [x] **TAG-03**: User can filter clipboard history by tag in overlay search (`tag:work`)
- [x] **TAG-04**: User can manage tags (rename, delete, set color) in Settings
- [x] **TAG-05**: Tags display as colored badges on overlay rows

### CLI

- [ ] **CLI-01**: User can list recent clipboard items from terminal (`clipass list`)
- [ ] **CLI-02**: User can copy/paste via terminal (`clipass copy`, `clipass paste`)
- [ ] **CLI-03**: User can delete/clear history from terminal
- [ ] **CLI-04**: User can manage tags from terminal (`clipass tag add/remove/list`)
- [ ] **CLI-05**: User can apply transforms from terminal (`clipass transform`)
- [ ] **CLI-06**: User can search clipboard history from terminal (`clipass search`)
- [ ] **CLI-07**: CLI outputs JSON with `--json` flag for scripting

### Pub/Sub

- [ ] **PUBSUB-01**: App broadcasts clipboard events over Unix socket
- [ ] **PUBSUB-02**: User can stream events to stdout via `clipass listen`
- [ ] **PUBSUB-03**: User can filter events by type, tag, or source app

### Action Chains

- [ ] **CHAIN-01**: User can create multi-step transform pipelines in Settings
- [ ] **CHAIN-02**: User can apply chains to items via overlay context menu
- [ ] **CHAIN-03**: User can run chains from terminal (`clipass chain`)

### QoL

- [ ] **QOL-01**: User can append to last copied item via hotkey (copy-append)
- [ ] **QOL-02**: User can pause/resume clipboard monitoring
- [ ] **QOL-03**: User can hide the menu bar icon

## v2.0 Requirements (Shipped)

### Overlay Panel

- [x] **OVRL-01**: User can summon a floating overlay panel via a dedicated global hotkey
- [x] **OVRL-02**: User can dismiss the overlay with ESC key
- [x] **OVRL-03**: User can dismiss the overlay by clicking outside the panel
- [x] **OVRL-04**: Same hotkey toggles overlay open/closed
- [x] **OVRL-05**: Search field is auto-focused when overlay opens
- [x] **OVRL-06**: User can navigate clipboard items with arrow keys and paste with Return
- [x] **OVRL-07**: Overlay displays frosted glass vibrancy background
- [x] **OVRL-08**: Overlay shows/hides with smooth animation
- [x] **OVRL-09**: User can configure the overlay hotkey in Settings

### Theming

- [x] **THME-01**: App ships with 4 predefined themes (Dark, Light, Midnight, Nord)
- [x] **THME-02**: User can select a theme from a new Appearance tab in Settings
- [x] **THME-03**: Selected theme persists across app restarts
- [x] **THME-04**: Theme picker shows live preview of each theme

### Inline Editor

- [x] **EDIT-01**: User can click a clipboard item in the overlay to enter edit mode
- [x] **EDIT-02**: User can modify the text and save changes
- [x] **EDIT-03**: User can cancel editing with ESC (without dismissing overlay)
- [x] **EDIT-04**: Edits sync to the menu bar popup immediately (SwiftData round-trip)

## Future Requirements

### Custom Theming

- **CTHM-01**: User can create custom themes with color picker
- **CTHM-02**: User can import/export theme files
- **CTHM-03**: Per-theme typography and density controls

### Visual Polish (v2.2)

- **VIS-01**: Preview pane for full content before pasting
- **VIS-02**: Collections/Pinboards built on tags
- **VIS-03**: OCR text extraction from copied images
- **VIS-04**: Drag & drop items from history into apps
- **VIS-05**: Snippet templates with variables
- **VIS-06**: Smart merge with transforms
- **VIS-07**: Transform live preview

## Out of Scope

| Feature | Reason |
|---------|--------|
| iCloud sync | Local-only by design, no cross-device sync |
| Rich media (images, files) | Text-only, simplifies transforms |
| Custom theme authoring (Theme Studio) | Defer to future milestone |
| Rich text / Markdown rendering in editor | Conflicts with transform model |
| Auto-triggered action chains | Security risk — chains are manual-only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| OVRL-01 | Phase 12 | Complete |
| OVRL-02 | Phase 12 | Complete |
| OVRL-03 | Phase 12 | Complete |
| OVRL-04 | Phase 12 | Complete |
| OVRL-05 | Phase 12 | Complete |
| OVRL-06 | Phase 12 | Complete |
| OVRL-07 | Phase 12 | Complete |
| OVRL-08 | Phase 12 | Complete |
| OVRL-09 | Phase 12 | Complete |
| THME-01 | Phase 13 | Complete |
| THME-02 | Phase 13 | Complete |
| THME-03 | Phase 13 | Complete |
| THME-04 | Phase 13 | Complete |
| EDIT-01 | Phase 14 | Complete |
| EDIT-02 | Phase 14 | Complete |
| EDIT-03 | Phase 14 | Complete |
| EDIT-04 | Phase 14 | Complete |
| TAG-01 | Phase 15 | Complete |
| TAG-02 | Phase 15 | Complete |
| TAG-03 | Phase 15 | Complete |
| TAG-04 | Phase 15 | Complete |
| TAG-05 | Phase 15 | Complete |
| CLI-01 | Phase 16 | Pending |
| CLI-02 | Phase 16 | Pending |
| CLI-03 | Phase 16 | Pending |
| CLI-06 | Phase 16 | Pending |
| CLI-07 | Phase 16 | Pending |
| CLI-04 | Phase 17 | Pending |
| PUBSUB-01 | Phase 17 | Pending |
| PUBSUB-02 | Phase 17 | Pending |
| PUBSUB-03 | Phase 17 | Pending |
| CHAIN-01 | Phase 18 | Pending |
| CHAIN-02 | Phase 18 | Pending |
| CHAIN-03 | Phase 18 | Pending |
| CLI-05 | Phase 18 | Pending |
| QOL-01 | Phase 19 | Pending |
| QOL-02 | Phase 19 | Pending |
| QOL-03 | Phase 19 | Pending |

**Coverage:**
- v2.1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-19 — v2.1 phase assignments added (phases 15-19)*
