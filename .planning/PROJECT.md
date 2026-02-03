# clipass

## What This Is

A macOS menu bar app for intelligent clipboard management. Access via menu bar icon or keyboard shortcut to browse clipboard history, apply smart transforms, and trigger automations. Text-only and local-first.

## Core Value

Smart transforms — auto-cleaning and formatting clipboard content before paste. The intelligence layer that makes this more than just clipboard history.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Clipboard history storage and recall
- [ ] Menu bar icon with popup UI
- [ ] Global keyboard shortcut to summon
- [ ] Transform rules (regex replacements, formatters)
- [ ] Auto-format on paste (e.g., remove trailing whitespace `\s+$` from terminal)
- [ ] External triggers on clipboard change (run scripts/apps)
- [ ] App-specific behavior based on source application

### Out of Scope

- Cloud sync — v1 is local-only, no cross-device sync
- Rich media (images, files) — text only for now, simplifies transforms

## Context

The name "clipass" blends clipboard + assistant (or cli + pass). The differentiator from existing clipboard managers is the event-driven transform system — rules that automatically clean and format content based on source app or content patterns.

Common use case: copying from Terminal includes trailing whitespace that breaks formatting elsewhere. Transform rules fix this automatically.

## Constraints

- **Tech stack**: Swift/SwiftUI — native macOS experience
- **Performance**: Menu bar popup must feel instant (<100ms response time)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Text-only v1 | Simplifies transform logic, rich media adds complexity | — Pending |
| Local-only v1 | Sync is a major feature, ship core value first | — Pending |
| Swift/SwiftUI | Native performance, system integration, modern Apple stack | — Pending |

---
*Last updated: 2026-02-03 after initialization*
