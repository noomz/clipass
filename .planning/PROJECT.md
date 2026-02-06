# clipass

## What This Is

A macOS menu bar app for intelligent clipboard management. Access via menu bar icon or Cmd+Shift+V to browse clipboard history, apply smart transforms, and trigger automations. Text-only and local-first.

## Core Value

Smart transforms — auto-cleaning and formatting clipboard content before paste. The intelligence layer that makes this more than just clipboard history.

## Current State

**Version:** v1.0 MVP (shipped 2026-02-05)

**Codebase:** 1,391 lines of Swift across 14 files

**Tech stack:** Swift/SwiftUI, SwiftData, KeyboardShortcuts

**What's working:**
- Menu bar popup with clipboard history (100 items max)
- Global hotkey Cmd+Shift+V
- Real-time search filtering
- Transform rules with regex patterns
- External hooks for automation scripts
- Dedicated Settings window

## Current Milestone: v1.1 More Control

**Goal:** Give users full control over filtering, display formatting, and app behavior through Settings.

**Target features:**
- Configurable ignored app patterns (replace hardcoded list)
- Content patterns to skip storing (regex)
- Display formatting (clean invisible chars, truncation length)
- Sensitive content redaction in preview (emails, passwords masked)
- History limits (max items, auto-cleanup age)
- Hotkey customization
- Start on login option

## Requirements

### Validated

- Clipboard history storage and recall — v1.0
- Menu bar icon with popup UI — v1.0
- Global keyboard shortcut to summon — v1.0
- Transform rules (regex replacements) — v1.0
- Auto-format on paste (strip trailing whitespace) — v1.0
- External triggers on clipboard change — v1.0
- App-specific behavior based on source — v1.0

### Active

- [ ] Configurable ignored app patterns
- [ ] Content patterns to ignore (regex)
- [ ] Clean invisible chars in menu preview
- [ ] Configurable preview truncation length
- [ ] Sensitive content redaction in preview
- [ ] History max items setting
- [ ] History auto-cleanup age setting
- [ ] Customizable global hotkey
- [ ] Start on login option

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
| Text-only v1 | Simplifies transform logic, rich media adds complexity | Good |
| Local-only v1 | Sync is a major feature, ship core value first | Good |
| Swift/SwiftUI | Native performance, system integration, modern Apple stack | Good |
| MenuBarExtra .window style | Enables custom popup UI vs standard menu | Good |
| 500ms polling interval | Balance between responsiveness and efficiency | Good |
| SwiftData for persistence | Modern Apple persistence, SQLite backend | Good |
| Window scene for Settings | Appears in app switcher (Settings scene doesn't) | Good |

---
*Last updated: 2026-02-06 after v1.1 milestone start*
