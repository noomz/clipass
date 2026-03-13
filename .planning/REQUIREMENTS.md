# Requirements: clipass

**Defined:** 2026-03-13
**Core Value:** Smart transforms — auto-cleaning and formatting clipboard content before paste

## v2.0 Requirements

Requirements for v2.0 Overlay UI & Theming. Each maps to roadmap phases.

### Overlay Panel

- [ ] **OVRL-01**: User can summon a floating overlay panel via a dedicated global hotkey
- [ ] **OVRL-02**: User can dismiss the overlay with ESC key
- [ ] **OVRL-03**: User can dismiss the overlay by clicking outside the panel
- [ ] **OVRL-04**: Same hotkey toggles overlay open/closed
- [ ] **OVRL-05**: Search field is auto-focused when overlay opens
- [ ] **OVRL-06**: User can navigate clipboard items with arrow keys and paste with Return
- [ ] **OVRL-07**: Overlay displays frosted glass vibrancy background
- [ ] **OVRL-08**: Overlay shows/hides with smooth animation
- [ ] **OVRL-09**: User can configure the overlay hotkey in Settings

### Theming

- [ ] **THME-01**: App ships with 4 predefined themes (Dark, Light, Midnight, Nord)
- [ ] **THME-02**: User can select a theme from a new Appearance tab in Settings
- [ ] **THME-03**: Selected theme persists across app restarts
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
| OVRL-01 | — | Pending |
| OVRL-02 | — | Pending |
| OVRL-03 | — | Pending |
| OVRL-04 | — | Pending |
| OVRL-05 | — | Pending |
| OVRL-06 | — | Pending |
| OVRL-07 | — | Pending |
| OVRL-08 | — | Pending |
| OVRL-09 | — | Pending |
| THME-01 | — | Pending |
| THME-02 | — | Pending |
| THME-03 | — | Pending |
| THME-04 | — | Pending |
| EDIT-01 | — | Pending |
| EDIT-02 | — | Pending |
| EDIT-03 | — | Pending |
| EDIT-04 | — | Pending |

**Coverage:**
- v2.0 requirements: 17 total
- Mapped to phases: 0
- Unmapped: 17

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-13 after initial definition*
