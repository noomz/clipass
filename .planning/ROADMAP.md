# Roadmap: clipass

## Overview

Build a macOS menu bar clipboard manager with intelligent transforms. Start with the foundation (menu bar shell + clipboard monitoring), add persistent history with search, implement the transform rule engine, then wire up external hooks and automations.

## Domain Expertise

None

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Foundation** - App skeleton, menu bar, clipboard monitoring ✓
- [x] **Phase 2: History** - Persistent storage, history UI, search ✓
- [ ] **Phase 3: Transforms** - Rule engine, regex transforms, app-specific rules
- [ ] **Phase 4: Hooks** - External triggers, event system

## Phase Details

### Phase 1: Foundation
**Goal**: Working menu bar app that monitors clipboard and captures text content
**Depends on**: Nothing (first phase)
**Research**: Likely (macOS clipboard APIs, menu bar patterns)
**Research topics**: NSPasteboard monitoring, menu bar app setup in SwiftUI, global hotkey registration
**Plans**: TBD

Plans:
- [x] 01-01: App skeleton with menu bar icon ✓
- [x] 01-02: Clipboard monitoring and global hotkey ✓

### Phase 2: History
**Goal**: Persistent clipboard history with searchable popup UI
**Depends on**: Phase 1
**Research**: Unlikely (internal patterns, standard persistence)
**Plans**: TBD

Plans:
- [x] 02-01: History storage and popup UI ✓
- [x] 02-02: Search and quick paste ✓

### Phase 3: Transforms
**Goal**: Rule engine that auto-transforms clipboard content based on patterns or source app
**Depends on**: Phase 2
**Research**: Unlikely (regex processing, internal rule engine)
**Plans**: TBD

Plans:
- [ ] 03-01: Transform rule engine
- [ ] 03-02: App-specific rules and config

### Phase 4: Hooks
**Goal**: External triggers that fire scripts/apps on clipboard events
**Depends on**: Phase 3
**Research**: Likely (external process launching, event patterns)
**Research topics**: Process launching APIs, macOS sandboxing implications, NSWorkspace
**Plans**: TBD

Plans:
- [ ] 04-01: Hook system and external triggers

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete | 2026-02-03 |
| 2. History | 2/2 | Complete | 2026-02-03 |
| 3. Transforms | 0/2 | Not started | - |
| 4. Hooks | 0/1 | Not started | - |
