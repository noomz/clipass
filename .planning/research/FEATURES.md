# Features Research: v1.1 More Control

**Domain:** macOS clipboard manager settings/configuration
**Researched:** 2026-02-06
**Confidence:** HIGH (based on Maccy, Clipy, LaunchAtLogin, KeyboardShortcuts research)

## Executive Summary

Research into macOS clipboard managers (Maccy 18.5k stars, Clipy 8.4k stars) and settings utilities (LaunchAtLogin, KeyboardShortcuts) reveals clear patterns for settings/configuration features. The ecosystem has well-established expectations around filtering, display, and app behavior settings.

Key insights:
- **Filtering**: Ignored apps by pasteboard type (not bundle ID) is the standard; content-based filtering via regex is differentiating
- **Display**: Preview truncation is table stakes; redaction of sensitive content varies widely
- **App behavior**: Launch at login is trivially implemented with `SMAppService`; hotkey customization via KeyboardShortcuts is already in clipass

---

## Filtering Settings

### Table Stakes
Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Pasteboard type ignore list** | Maccy, Clipy, and all major managers do this | Low | None | Already partially implemented via hardcoded `ignoredTypes` |
| **Editable ignored types list** | Power users need to add app-specific types | Low | Settings persistence | UI: List with add/remove, text input |
| **Ignore secure/concealed types** | Standard privacy protection | Low | None | Already implemented - `TransientType`, `ConcealedType` |
| **Toggle for ignore list** | Users may want to temporarily disable filtering | Low | None | Simple on/off toggle in Settings |

### Differentiators
Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **Content pattern ignore (regex)** | Skip storing sensitive data by content, not just source | Medium | Regex engine | Unique - most managers only filter by source |
| **Configurable ignored apps by bundle ID** | More intuitive than pasteboard types for users | Medium | App picker UI | Current impl uses pasteboard types, which is technical |
| **Pattern presets** | Pre-configured patterns for common cases (API keys, passwords) | Low | Content patterns | Starter patterns users can enable/disable |
| **Per-pattern enable/disable** | Fine-grained control without deleting patterns | Low | Pattern list | Similar to transform rules UI |

### Anti-Features
Features to deliberately NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Automatic sensitive content detection** | False positives frustrating; privacy concerns about analyzing all content | Let users define their own patterns |
| **AI-based content classification** | Overkill for v1.1; battery/performance impact | Simple regex patterns |
| **Cloud-synced ignore lists** | Scope creep; v1 is local-only | Store in UserDefaults or SwiftData |
| **Real-time pattern testing feedback** | Complex UI; diminishing returns | Test patterns manually or show match count |

---

## Display Settings

### Table Stakes
Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Configurable preview truncation length** | Maccy, Clipy all have this | Low | None | Currently appears to be hardcoded |
| **Clean invisible chars in preview** | Common frustration with copy/paste | Low | String sanitization | Tab, newline, zero-width chars shown as symbols or removed |
| **Preview line limit** | Prevent long multi-line text overwhelming UI | Low | None | Separate from char truncation |

### Differentiators
Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **Sensitive content redaction in preview** | Security-conscious users see masked data in menu | Medium | Regex detection | Show `j***@e***` for emails, `•••••••` for passwords |
| **Configurable redaction patterns** | User-defined patterns for masking | Medium | Pattern system | Reuse ignore pattern infrastructure |
| **Show/hide source app name** | Some users want cleaner UI | Low | None | Toggle in display settings |
| **Timestamp display format** | Relative ("2m ago") vs absolute | Low | None | User preference for time display |
| **Monospace font option** | Better for code snippets | Low | None | Helps developers |

### Anti-Features
Features to deliberately NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Syntax highlighting in preview** | Performance overhead; complex implementation | Keep preview simple, show raw text |
| **Rich text preview** | Clipass is text-only; adds complexity | Show plain text preview |
| **Multiple preview themes** | Feature creep; diminishing value | Single well-designed preview style |
| **Image thumbnails** | v1 is text-only per design constraints | Text preview only |

---

## App Behavior Settings

### Table Stakes
Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Launch at Login toggle** | Every menu bar app has this | Very Low | LaunchAtLogin-Modern package | `LaunchAtLogin.Toggle()` SwiftUI component |
| **Customizable global hotkey** | KeyboardShortcuts already integrated | Very Low | KeyboardShortcuts package | `KeyboardShortcuts.Recorder` in Settings |
| **History max items setting** | Maccy has this; controls storage/performance | Low | Currently hardcoded at 100 | Slider or text field, reasonable range 50-1000 |
| **Clear history action** | Users need to purge sensitive history | Low | None | Button in Settings or menu |

### Differentiators
Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **History auto-cleanup by age** | Auto-delete items older than X days | Medium | Background task or on-launch check | Reduces storage bloat |
| **Ignore next copy temporarily** | One-time skip without changing settings | Low | State management | Maccy has this: Option+Shift+click menu icon |
| **Pause/Resume monitoring** | Temporarily stop all capture | Low | State management | Toggle in menu bar icon |
| **Clipboard check interval** | Advanced tuning (Maccy default 500ms) | Low | Timer config | Only for power users; may hide in advanced |
| **Sound on copy** | Audio feedback (optional) | Low | System sound API | Accessibility feature |

### Anti-Features
Features to deliberately NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Auto-start enabled by default** | Mac App Store guidelines require user action | Default to OFF; prompt user to enable |
| **Cloud sync of settings** | Scope creep; v1 is local-only | Local settings storage |
| **Multiple profiles** | Complexity without clear value | Single settings profile |
| **Scheduled clear times** | Edge case; manual clear sufficient | On-demand clear action |
| **Export/import settings** | v1.1 scope creep | Consider for future version |

---

## Hotkey Customization Settings

### Table Stakes

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Hotkey recorder UI** | KeyboardShortcuts provides this | Very Low | Already integrated | Use `KeyboardShortcuts.Recorder` |
| **Conflict detection** | KeyboardShortcuts handles this | Very Low | Already integrated | Shows warning if shortcut used by system |
| **Clear/reset hotkey** | Users may want to remove hotkey | Very Low | KeyboardShortcuts API | Built into Recorder component |

### Differentiators

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **Multiple hotkeys** | Different shortcuts for different actions | Medium | KeyboardShortcuts supports this | e.g., separate hotkey for Settings window |
| **Double-tap shortcut** | Alternative activation method | High | Custom implementation | Not worth complexity for v1.1 |

---

## Feature Dependencies

```
Filtering Settings
├── Ignored Types List (existing) → Editable UI
├── Content Patterns → Regex Engine
│   └── Pattern Presets (depends on Content Patterns)
└── Ignore Apps → App Picker UI

Display Settings
├── Preview Truncation → Settings Storage
├── Clean Invisible Chars → Text Processing
└── Sensitive Redaction → Regex Detection (shares with Content Patterns)

App Behavior
├── Launch at Login → LaunchAtLogin-Modern package (new dependency)
├── Hotkey Customization → KeyboardShortcuts (existing)
├── History Limits → Settings Storage
└── Auto-Cleanup → Background Task
```

---

## MVP Recommendation

For v1.1 MVP, prioritize:

**Phase 1 (Foundation):**
1. Settings persistence infrastructure (UserDefaults or @AppStorage)
2. General tab in Settings view

**Phase 2 (Filtering):**
3. Editable ignored pasteboard types list
4. Content ignore patterns (regex) with add/remove UI

**Phase 3 (Display):**
5. Configurable preview truncation length
6. Clean invisible characters toggle
7. Basic sensitive content redaction (email, password patterns)

**Phase 4 (Behavior):**
8. Launch at Login toggle (LaunchAtLogin-Modern)
9. History max items slider
10. Global hotkey customization (KeyboardShortcuts.Recorder)
11. History auto-cleanup by age

**Defer to post-v1.1:**
- Advanced redaction pattern customization
- Clipboard check interval tuning
- Pause/resume monitoring
- Multiple hotkeys
- Sound on copy

---

## Common Patterns (Implementation Guidance)

### Pasteboard Type Ignore Patterns (from Maccy)

Standard types that should always be ignored:
```swift
// Core privacy types - always ignore
"org.nspasteboard.TransientType"      // Temporary/internal
"org.nspasteboard.ConcealedType"      // Secret content
"org.nspasteboard.AutoGeneratedType"  // Auto-generated

// Common app-specific confidential types
"com.agilebits.onepassword"           // 1Password
"com.typeit4me.clipping"              // TypeIt4Me
"de.petermaurer.TransientPasteboardType"  // LaunchBar
"Pasteboard generator type"           // Various
"net.antelle.keeweb"                  // KeeWeb
"com.apple.is-remote-clipboard"       // Universal Clipboard (optional)
```

### Common Redaction Patterns

```swift
// Email: show first char + *** + @ + first char of domain + ***
// "john@example.com" → "j***@e***"
let emailPattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/

// Password fields (commonly labeled)
let passwordLabelPatterns = [
    /password[:\s]*.+/i,
    /pwd[:\s]*.+/i,
    /secret[:\s]*.+/i
]

// API keys (common formats)
let apiKeyPatterns = [
    /sk-[a-zA-Z0-9]{32,}/,           // OpenAI-style
    /ghp_[a-zA-Z0-9]{36}/,           // GitHub PAT
    /[A-Za-z0-9_]{32,}==/,           // Base64 tokens
]

// Credit cards (basic, not comprehensive)
let ccPattern = /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/
```

### Launch at Login (from LaunchAtLogin-Modern)

```swift
import LaunchAtLogin

// In Settings view:
LaunchAtLogin.Toggle()
// or custom:
Toggle("Launch at Login", isOn: $launchAtLogin.isEnabled)

// Programmatic:
LaunchAtLogin.isEnabled = true
```

### Hotkey Customization (KeyboardShortcuts - already integrated)

```swift
import KeyboardShortcuts

// In Settings view:
KeyboardShortcuts.Recorder("Global Hotkey:", name: .toggleClipboard)
```

---

## Sources

| Source | Type | Confidence | Notes |
|--------|------|------------|-------|
| [Maccy](https://github.com/p0deje/Maccy) | GitHub (18.5k stars) | HIGH | Most popular open-source macOS clipboard manager |
| [Clipy](https://github.com/Clipy/Clipy) | GitHub (8.4k stars) | HIGH | Popular clipboard extension |
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | GitHub (549 stars) | HIGH | Standard for launch-at-login in macOS 13+ |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | GitHub (2.5k stars) | HIGH | Already used in clipass |
| [Maccy README](https://github.com/p0deje/Maccy/blob/master/README.md) | Official docs | HIGH | Documents ignore types, clipboard interval |
| Training data | Claude knowledge | MEDIUM | General macOS development patterns |
