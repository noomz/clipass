# Requirements: clipass

**Defined:** 2026-02-06
**Core Value:** Smart transforms — auto-cleaning and formatting clipboard content before paste

## v1.1 Requirements

Requirements for v1.1 "More Control" milestone. Each maps to roadmap phases.

### Filtering

- [ ] **FILT-01**: User can view and edit the list of ignored app patterns in Settings
- [ ] **FILT-02**: User can add content ignore patterns (regex) to skip storing certain clipboard content
- [ ] **FILT-03**: User can enable/disable individual ignore patterns without deleting them

### Display

- [ ] **DISP-01**: User can configure preview truncation length in Settings
- [ ] **DISP-02**: Menu preview cleans invisible characters (newlines, tabs shown as symbols or removed)
- [ ] **DISP-03**: Sensitive content (emails, passwords) is redacted in menu preview but stored in full

### App Behavior

- [ ] **BEHV-01**: User can enable/disable "Launch at Login" in Settings
- [ ] **BEHV-02**: User can configure maximum history items in Settings
- [ ] **BEHV-03**: User can customize the global hotkey in Settings
- [ ] **BEHV-04**: User can configure auto-cleanup age (delete items older than X days)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Filtering

- **FILT-04**: Pre-configured pattern presets for common cases (API keys, passwords)
- **FILT-05**: Configurable ignored apps by bundle ID (more intuitive than pasteboard types)

### Display

- **DISP-04**: Show/hide source app name toggle
- **DISP-05**: Timestamp display format options (relative vs absolute)

### App Behavior

- **BEHV-05**: Clear history action (manual purge)
- **BEHV-06**: Pause/resume monitoring toggle in menu
- **BEHV-07**: Clipboard check interval tuning (advanced)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Automatic sensitive content detection | False positives frustrating; let users define patterns |
| AI-based content classification | Overkill; battery/performance impact |
| Cloud sync of settings | v1 is local-only |
| Syntax highlighting in preview | Performance overhead; keep preview simple |
| Rich text preview | clipass is text-only by design |
| Multiple settings profiles | Complexity without clear value |
| Export/import settings | Scope creep for v1.1 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FILT-01 | — | Pending |
| FILT-02 | — | Pending |
| FILT-03 | — | Pending |
| DISP-01 | — | Pending |
| DISP-02 | — | Pending |
| DISP-03 | — | Pending |
| BEHV-01 | — | Pending |
| BEHV-02 | — | Pending |
| BEHV-03 | — | Pending |
| BEHV-04 | — | Pending |

**Coverage:**
- v1.1 requirements: 10 total
- Mapped to phases: 0
- Unmapped: 10

---
*Requirements defined: 2026-02-06*
*Last updated: 2026-02-06 after initial definition*
