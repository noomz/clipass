# Research Summary: v1.1 More Control

**Synthesized:** 2026-02-06
**Files Reviewed:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md
**Overall Confidence:** HIGH

---

## Executive Summary

clipass v1.1 adds user-configurable settings to a well-architected SwiftUI/SwiftData menu bar app. The existing codebase already has clean patterns (Services layer, tabbed Settings window, consistent model design) that make integration straightforward. **Only one new dependency is needed** (LaunchAtLogin-Modern), with everything else leveraging existing stack components (KeyboardShortcuts, SwiftData, Swift Regex, @AppStorage).

The recommended approach follows the existing architecture: add SwiftData models for list-based settings (ignored apps, patterns), use @AppStorage for scalar settings (limits, toggles), create a RedactionEngine service following the TransformEngine pattern, and extend the Settings TabView with new tabs.

Key risks center on **SwiftData schema migration** (adding new models to existing container), **regex performance** (cache compiled patterns), and **LaunchAtLogin App Store guidelines** (never auto-enable). All are well-documented with clear prevention strategies.

---

## Stack Additions

| Component | Purpose | Status |
|-----------|---------|--------|
| **LaunchAtLogin-Modern** | "Start on login" toggle | NEW — `from: "1.1.0"` |
| KeyboardShortcuts.Recorder | Hotkey customization UI | Existing |
| @AppStorage | Scalar settings (limits, toggles) | Existing |
| SwiftData models | List settings (ignored apps/patterns) | Existing |
| Swift Regex | Pattern matching | Existing |

**Package.swift change:** Add one line:
```swift
.package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.1.0")
```

---

## Feature Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Complexity | Dependencies |
|---------|------------|--------------|
| Launch at login toggle | Very Low | LaunchAtLogin-Modern |
| Customizable global hotkey | Very Low | KeyboardShortcuts (existing) |
| Configurable preview truncation | Low | @AppStorage |
| History max items setting | Low | @AppStorage |
| Clean invisible chars in preview | Low | String sanitization |
| Clear history action | Low | None |
| Editable ignored pasteboard types | Low | Settings persistence |

---

## Feature Differentiators

Features that set clipass apart from Maccy/Clipy.

| Feature | Value Proposition | Complexity |
|---------|-------------------|------------|
| **Content pattern ignore (regex)** | Skip storing by content, not just source | Medium |
| **Sensitive content redaction** | Show `j***@e***` for emails in preview | Medium |
| **History auto-cleanup by age** | Auto-delete items older than X days | Medium |
| **Ignored apps by bundle ID** | More intuitive than pasteboard types | Medium |
| **Pattern presets** | Pre-configured patterns for API keys, passwords | Low |

**Defer to post-v1.1:**
- Multiple hotkeys for different actions
- Clipboard check interval tuning
- Pause/resume monitoring
- Sound on copy

---

## Architecture Impact

### New Models (4 files)

| Model | Purpose |
|-------|---------|
| `IgnoredApp.swift` | Bundle IDs to skip capturing |
| `IgnoredPattern.swift` | Regex patterns for content to skip |
| `DisplaySettings.swift` | Preview config (singleton) |
| `AppSettings.swift` | Behavior config (singleton) |

### New Service (1 file)

| Service | Purpose |
|---------|---------|
| `RedactionEngine.swift` | Clean invisible chars, apply sensitive pattern redaction |

### Modified Components

| File | Changes |
|------|---------|
| `clipassApp.swift` | Register new models in ModelContainer |
| `ClipboardMonitor.swift` | Query ignored apps/patterns, use settings for limits |
| `HistoryItemRow.swift` | Use RedactionEngine, read previewLength from settings |
| `SettingsView.swift` | Add General, Ignored Apps, Ignored Patterns, Display tabs |

### Data Flow Change

```
Before (v1.0):
  Clipboard → hardcoded filters → transform → save → prune(100) → hooks

After (v1.1):
  Clipboard → hardcoded filters → IgnoredApp check → IgnoredPattern check
           → transform → save → prune(settings.maxItems) → hooks
  
Display:
  item.content → RedactionEngine.cleanForDisplay() → truncate(settings.previewLength)
```

---

## Critical Pitfalls

### 1. LaunchAtLogin Auto-Enable = App Store Rejection
**Severity:** CRITICAL

Never auto-enable launch at login. Apple requires explicit user action.

```swift
// WRONG
if isFirstLaunch { LaunchAtLogin.isEnabled = true }

// CORRECT
LaunchAtLogin.Toggle() // User toggles explicitly
```

### 2. SwiftData Schema Migration Crashes
**Severity:** CRITICAL

Adding new models (IgnoredApp, etc.) to existing ModelContainer can crash on launch if migration fails.

**Prevention:** Implement graceful recovery — delete corrupted database and create fresh if migration fails.

### 3. Breaking Existing TransformRule/Hook Data
**Severity:** CRITICAL

Never add required (non-optional) properties to existing models.

```swift
// WRONG
var newProperty: String  // Crashes existing data

// CORRECT
var newProperty: String?  // Optional, backward compatible
```

### 4. Regex Compilation on Every Poll
**Severity:** MEDIUM

Compiling regex patterns on every 500ms poll wastes CPU. Cache compiled patterns, invalidate on rule edit.

### 5. User-Supplied Regex Without Validation
**Severity:** MEDIUM

Invalid regex patterns cause silent failures. Add real-time validation with clear error messages in rule editor UI.

---

## Recommended Build Order

### Phase 1: Foundation (Models & Settings Shell)
**Goal:** Data layer for all settings, basic UI structure

- Create 4 new model files
- Update `clipassApp.swift` to register models
- Add placeholder tabs to SettingsView
- Implement SwiftData migration safety

**Must avoid:** Pitfall #8 (schema migration), Pitfall #14 (breaking data)

### Phase 2: Ignored Apps
**Goal:** User can manage ignored apps, filtering works

- Create `IgnoredAppsView.swift` with list UI
- Modify ClipboardMonitor to check IgnoredApp
- Test filtering behavior

**Validates:** Pattern for Phase 3

### Phase 3: Ignored Patterns
**Goal:** User can manage content patterns to skip

- Create `IgnoredPatternsView.swift` with list UI
- Modify ClipboardMonitor to check IgnoredPattern
- Implement regex validation in editor

**Must avoid:** Pitfall #5 (invalid regex), Pitfall #6 (ReDoS)

### Phase 4: Display Settings & Redaction
**Goal:** Configurable display with sensitive content redaction

- Create `RedactionEngine.swift` service
- Create `DisplaySettingsView.swift` UI
- Modify HistoryItemRow to use RedactionEngine
- Implement invisible char cleaning and sensitive pattern redaction

**Isolated change:** Display-only, no impact on data storage

### Phase 5: History & App Settings
**Goal:** Configurable limits, start on login, hotkey UI

- Create `GeneralSettingsView.swift`
- Modify ClipboardMonitor.pruneOldItems() to use settings
- Add age-based cleanup logic
- Add KeyboardShortcuts.Recorder
- Add LaunchAtLogin.Toggle

**Must avoid:** Pitfall #1 (auto-enable), Pitfall #11 (hotkey conflicts), Pitfall #13 (cached values)

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Single well-documented dependency (LaunchAtLogin-Modern) |
| Features | HIGH | Based on Maccy (18.5k stars), Clipy (8.4k stars) analysis |
| Architecture | HIGH | Based on direct codebase analysis, matches existing patterns |
| Pitfalls | HIGH | Verified from official packages and real GitHub issues |

### Gaps to Address During Implementation

1. **SwiftData migration testing** — Need to verify adding models to existing container works
2. **Redaction pattern effectiveness** — Test email/password patterns against real-world content
3. **Ignore visibility** — Consider showing ignored items in collapsed section for debugging

---

## Sources

### Stack
- LaunchAtLogin-Modern: https://github.com/sindresorhus/LaunchAtLogin-Modern (v1.1.0)
- KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts (v2.4.0)

### Features
- Maccy: https://github.com/p0deje/Maccy (18.5k stars)
- Clipy: https://github.com/Clipy/Clipy (8.4k stars)

### Architecture
- Direct clipass codebase analysis

### Pitfalls
- LaunchAtLogin-Modern README (App Store guidelines)
- LaunchAtLogin-Legacy FAQ (testing issues)
- SwiftData migration PR: https://github.com/Geoffe-Ga/wrist-arcana/pull/47
