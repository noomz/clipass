# Requirements: clipass

**Defined:** 2026-03-13
**Core Value:** Smart transforms — auto-cleaning and formatting clipboard content before paste

## v2.0 Requirements

Requirements for v2.0 Overlay UI & Theming. Each maps to roadmap phases.

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
- [ ] **THME-02**: User can select a theme from a new Appearance tab in Settings
- [x] **THME-03**: Selected theme persists across app restarts
- [ ] **THME-04**: Theme picker shows live preview of each theme

### Inline Editor

- [ ] **EDIT-01**: User can click a clipboard item in the overlay to enter edit mode
- [ ] **EDIT-02**: User can modify the text and save changes
- [ ] **EDIT-03**: User can cancel editing with ESC (without dismissing overlay)
- [ ] **EDIT-04**: Edits sync to the menu bar popup immediately (SwiftData round-trip)

## Future Requirements

### Custom Theming

- **CTHM-01**: User can create custom themes with color picker
- **CTHM-02**: User can import/export theme files
- **CTHM-03**: Per-theme typography and density controls

## Out of Scope

| Feature | Reason |
|---------|--------|
| Custom theme authoring (Theme Studio) | No reference implementation found; Raycast's is Pro-only. Defer to future milestone |
| Rich text / Markdown rendering in editor | Conflicts with transform model; massive complexity increase |
| Drag-to-reorder in overlay | Fragile in transient overlay; pin/unpin from v1.1 handles priority |
| Overlay search persistence between invocations | Adds state management complexity for marginal UX gain |
| Theme applied to menu bar popup | Menu bar popup retains existing style; overlay is the themed surface |

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
| THME-02 | Phase 13 | Pending |
| THME-03 | Phase 13 | Complete |
| THME-04 | Phase 13 | Pending |
| EDIT-01 | Phase 14 | Pending |
| EDIT-02 | Phase 14 | Pending |
| EDIT-03 | Phase 14 | Pending |
| EDIT-04 | Phase 14 | Pending |

**Coverage:**
- v2.0 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-13 — traceability filled after roadmap creation*
