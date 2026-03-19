# clipass

## What This Is

A macOS menu bar app for intelligent clipboard management. Access via menu bar icon or Cmd+Shift+V to browse clipboard history, apply smart transforms, trigger automations, and perform smart context actions. Text-only and local-first with full user control over filtering, display, and behavior.

## Core Value

Smart transforms — auto-cleaning and formatting clipboard content before paste. The intelligence layer that makes this more than just clipboard history.

## Current Milestone: v2.1 Polish & Competitive Features

**Goal:** Add polish and competitive features to make clipass a compelling free alternative to paid clipboard managers.

**Target features:**
- TBD — researching competitors (Maccy, ClipBook, Paste, Pastebot) to identify gaps and opportunities

## Current State

**Version:** v1.1 More Control (shipped 2026-03-13)

**Codebase:** 8,014 lines of Swift across 50 files

**Tech stack:** Swift/SwiftUI, SwiftData, KeyboardShortcuts, LaunchAtLogin-Modern

**What's working:**
- Menu bar popup with clipboard history (configurable max items)
- Customizable global hotkey (default Cmd+Shift+V)
- Real-time search filtering
- Transform rules with regex patterns
- External hooks for automation scripts
- macOS-native Settings with 6 tabs (General, Transforms, Automation, Filtering, Display, Actions)
- App/content ignore patterns with regex
- Display formatting with sensitive content redaction
- Launch at Login, auto-cleanup timer
- Smart content-aware context menu (URL, email, JSON, path detection)
- Pin/Unpin items (exempt from cleanup/pruning)
- Custom user-defined shell-command actions

## Requirements

### Validated

- Clipboard history storage and recall — v1.0
- Menu bar icon with popup UI — v1.0
- Global keyboard shortcut to summon — v1.0
- Transform rules (regex replacements) — v1.0
- Auto-format on paste (strip trailing whitespace) — v1.0
- External triggers on clipboard change — v1.0
- App-specific behavior based on source — v1.0
- Configurable ignored app patterns — v1.1
- Content patterns to ignore (regex) — v1.1
- Clean invisible chars in menu preview — v1.1
- Configurable preview truncation length — v1.1
- Sensitive content redaction in preview — v1.1
- History max items setting — v1.1
- History auto-cleanup age setting — v1.1
- Customizable global hotkey — v1.1
- Start on login option — v1.1

### Active

- TBD — defining after competitive research

### Out of Scope

- Cloud sync — local-only, no cross-device sync
- Rich media (images, files) — text only, simplifies transforms

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
| sidebarAdaptable TabView | macOS 15+ native Settings style with legacy fallback | Good |
| ContentAnalyzer for smart menus | Lightweight regex detection gates context actions | Good |
| isPinned on ClipboardItem | Exempt from all pruning paths, simple SwiftData field | Good |
| ContextAction shell commands | Flexible user-defined actions via CLIPASS_CONTENT env var | Good |

---
*Last updated: 2026-03-19 after v2.1 milestone started*
