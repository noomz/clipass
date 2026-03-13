# Feature Landscape

**Domain:** macOS clipboard manager — overlay UI, Raycast-style theming, inline text editor
**Researched:** 2026-03-13
**Milestone:** v2.0 Overlay UI & Theming

---

## Context: What Already Exists (Do Not Duplicate)

v1.1 shipped all of the below. v2.0 adds new surfaces and behaviors on top:

- Menu bar popup (`ClipboardPopup.swift`) via `MenuBarExtra .window` style
- Global hotkey Cmd+Shift+V via `KeyboardShortcuts` package
- `HistoryItemRow.swift` with search, smart context menu, pin/unpin
- Transform rules, hooks, context actions
- Settings window with 6 tabs (General, Transforms, Automation, Filtering, Display, Actions)
- Persistence via SwiftData (`ClipboardItem` model)

The v2.0 overlay is a **second UI surface** — not a replacement. Both coexist with separate hotkeys and separate purposes.

---

## Table Stakes

Features users expect from a Raycast-style overlay and theme system. Missing any of these makes the feature feel broken or incomplete.

| Feature | Why Expected | Complexity | Depends On |
|---------|--------------|------------|------------|
| Floating center-screen panel | Every launcher (Raycast, Alfred, Spotlight) positions here | Low | NSPanel + NSHostingView |
| Separate global hotkey to summon | Core activation model, distinct from existing Cmd+Shift+V | Low | KeyboardShortcuts (already in project) |
| Toggle: same hotkey closes overlay | Users expect hotkey to dismiss if already open | Low | Panel `isVisible` check |
| ESC dismisses overlay | Universal dismissal convention across all macOS launchers | Low | `.onExitCommand` in SwiftUI |
| Click outside dismisses overlay | Standard floating window behavior | Low | `NSWindowDelegate.windowDidResignKey` |
| Search field auto-focused on open | Without auto-focus, user must click to type — feels broken | Low | `@FocusState` + `.onAppear` |
| Keyboard navigation (↑↓ arrows) | Mouse-free use is the point of a launcher overlay | Medium | Reuse selection pattern from `ClipboardPopup.swift` |
| Return/Enter pastes selected item | Primary action; same as menu bar popup | Low | Reuse existing paste service |
| Vibrancy / blur background | macOS visual convention for floating overlay panels | Low | `NSVisualEffectView` via `NSHostingView`; or `.ultraThinMaterial` |
| Smooth appear/dismiss animation | Instant show/hide feels cheap; ~150ms opacity+scale | Low | SwiftUI transition modifiers |
| `hidesOnDeactivate` on app switch | Standard overlay behavior: hide when user Cmd+Tabs away | Low | `NSPanel.hidesOnDeactivate = true` |
| Predefined themes (light, dark, at minimum) | Without presets it is not a theme system | Medium | Semantic token enum |
| Theme persists across launches | Settings change survives restart | Low | `AppStorage` / `UserDefaults` |

## Differentiators

Features that set clipass v2.0 apart from competing clipboard managers (Maccy, Pasta, Pastebot).

| Feature | Value Proposition | Complexity | Depends On |
|---------|-------------------|------------|------------|
| Click-to-edit inline text editor (overlay only) | Edit clipboard content before pasting — no free clipboard manager does this | High | Overlay panel; two-state row; temporary text buffer; SwiftData write |
| Raycast-style accent color token system | Matches user aesthetic; feels like a first-class app | Medium | Semantic color token structs + SwiftUI environment injection |
| 3–5 curated named themes (Dark, Light, High Contrast, at least one accent) | Predefined quality themes reduce configuration burden | Medium | Token enum with named cases |
| Theme picker in Settings (live preview) | Immediate visual feedback before committing | Low | Theme system + existing Settings window |
| Overlay-only feature scope for editor | Keeps menu bar popup fast and simple; overlay is the "power" surface | Low | Architecture decision — no code complexity |

## Anti-Features

Features to explicitly NOT build in v2.0.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Rich text / Markdown rendering in inline editor | NSTextView attributed strings + clipass transform model = conflict; massive complexity | Plain text only — existing transforms already handle formatting |
| Drag-to-reorder inside overlay | Fragile UX in a transient overlay; pin/unpin in v1.1 handles priority | Keyboard-only; use pin to preserve important items |
| Overlay replaces menu bar popup | Two surfaces solve different UX needs; removal breaks existing users | Keep both; document distinction |
| Custom theme authoring / Theme Studio UI | High complexity; Raycast's equivalent is Pro-only; not MVP | Named predefined themes only for v2.0; defer custom builder |
| Theme import/export | Scope creep; no community infrastructure yet | Local themes only |
| Positioning overlay at mouse cursor | Multi-monitor behavior unpredictable; cursor position changes between shortcut press and panel render | Always center on active display |
| iCloud/cloud theme sync | Project is local-only by design | `UserDefaults` / `AppStorage` only |
| Per-item undo history in editor | Adds state complexity without clear demand | SwiftUI `TextEditor` built-in undo is sufficient |
| Inline editor in menu bar popup | Keeps popup fast; editing belongs in the persistent overlay surface | Editor in overlay only |

---

## Feature Dependencies

```
Overlay Panel (NSPanel + SwiftUI hosting)
  ├── Separate global hotkey .............. KeyboardShortcuts package (already in project)
  ├── Toggle show/hide ................... depends on panel existing + isVisible state
  ├── ESC dismiss ........................ .onExitCommand modifier (SwiftUI)
  ├── Click-outside dismiss .............. NSWindowDelegate.windowDidResignKey
  ├── hidesOnDeactivate .................. NSPanel property
  ├── Search auto-focus .................. @FocusState + .onAppear
  ├── Keyboard navigation ................ reuse selection pattern from ClipboardPopup.swift
  ├── Return-to-paste .................... reuse paste service (already exists)
  └── Vibrancy background ................ NSVisualEffectView or .ultraThinMaterial

Theme System (semantic color tokens via SwiftUI environment)
  ├── Token struct ....................... background, surface, accent, textPrimary, textSecondary
  ├── Theme enum with named cases ........ prerequisite for everything theming
  ├── Environment injection .............. .environment(\.appTheme, currentTheme)
  ├── AppStorage persistence ............. @AppStorage("selectedTheme") in AppDelegate or app state
  ├── Settings theme picker .............. depends on theme enum + existing Settings window
  ├── Overlay applies theme .............. overlay depends on theme system
  └── Menu bar popup respects theme ...... parallel track; share same environment value

Click-to-edit Inline Editor (overlay only — hard dependency on overlay panel)
  ├── Overlay panel must exist ........... hard dependency
  ├── HistoryItemRow edit-mode variant ... new @State .display / .editing on row
  ├── @FocusState within row ............. manage focus for the TextEditor
  ├── Temporary text buffer .............. edit without mutating SwiftData on every keystroke
  ├── Commit path ........................ Return key → update ClipboardItem.content in SwiftData
  ├── Cancel path ........................ ESC → discard temp buffer, return to display mode
  └── ESC conflict resolution ............ if row.isEditing: ESC cancels edit (not overlay dismiss)
                                          if not editing: ESC dismisses overlay
```

---

## MVP Recommendation

Minimum for v2.0 to be shippable:

**Phase 1 — Overlay panel foundation**
Everything else depends on this. Build NSPanel hosting infrastructure, hotkey, toggle, ESC, click-outside, search auto-focus, arrow navigation, Return-to-paste, vibrancy.

**Phase 2 — Theme system**
Token structs, Theme enum (Dark / Light / High Contrast / one accent variant), SwiftUI environment injection, AppStorage persistence, theme picker in Settings Display tab with live preview.

**Phase 3 — Inline editor**
Two-state `HistoryItemRow` (display/edit), `TextEditor` bound to temp buffer, commit on Return, cancel on ESC, ESC conflict resolution.

Defer to a later milestone:
- Custom theme creation UI
- Theme import/export
- Per-theme typography or density controls
- Overlay search query persistence between invocations
- Cmd+Return "copy without closing" action

---

## Expected UX Behaviors (Reference)

### Overlay panel lifecycle
| Trigger | Behavior |
|---------|----------|
| Hotkey when closed | Show overlay, center on active display, focus search field |
| Hotkey when open | Hide overlay (toggle) |
| ESC when not editing | Hide overlay |
| Click outside panel | Hide overlay |
| Cmd+Tab / app loses focus | Hide overlay (`hidesOnDeactivate`) |
| Return on selected item | Paste item, hide overlay |

### Keyboard navigation
| Key | Action |
|-----|--------|
| Any printable character | Filters history (search is always active) |
| ↑ / ↓ | Move selection through filtered list |
| Return | Paste selected item and close overlay |
| ESC (no edit active) | Dismiss overlay |

### Inline editor lifecycle
| Trigger | Behavior |
|---------|----------|
| Double-click or Edit button on row | Enter edit mode; row expands to multiline TextEditor |
| Return / Save button | Commit changes to SwiftData, exit edit mode |
| ESC while editing | Discard changes, exit edit mode (does NOT dismiss overlay) |
| ESC while not editing | Dismiss overlay as normal |

### Theme application
| Event | Behavior |
|-------|----------|
| Theme changed in Settings | Applies live without restart |
| System dark/light toggle | Default themes follow system; explicit user-chosen theme stays fixed |
| Overlay opened | Renders with currently active theme |

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Overlay panel patterns (NSPanel) | HIGH | Official Apple HIG Panels docs + multiple 2025/2026 SwiftUI guides |
| Keyboard UX conventions | HIGH | Raycast manual + macOS launcher ecosystem — consistent across sources |
| Theme system (SwiftUI env + tokens) | HIGH | SwiftUI official docs + multiple 2025 production-scale guides |
| Click-to-edit pattern | MEDIUM | polpiella.dev guide documents the exact pattern; no Apple-official "inline edit" primitive |
| Vibrancy / blur implementation | HIGH | NSVisualEffectView is official Apple API; `.ultraThinMaterial` in SwiftUI |
| Custom theme authoring scope | LOW | Raycast's is Pro-gated; no reference open-source implementation found |

---

## Sources

- [Apple HIG: Panels](https://developer.apple.com/design/human-interface-guidelines/panels)
- [Cindori: Make a floating panel in SwiftUI for macOS](https://cindori.com/developer/floating-panel)
- [SwiftUI/macOS: Floating Window/Panel — Level Up Coding](https://levelup.gitconnected.com/swiftui-macos-floating-window-panel-4eef94a20647)
- [polpiella.dev: Making macOS SwiftUI text views editable on click](https://www.polpiella.dev/swiftui-editable-list-text-items)
- [NSVisualEffectView — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsvisualeffectview)
- [Raycast manual: Keyboard Shortcuts](https://manual.raycast.com/keyboard-shortcuts)
- [Raycast: Custom Themes](https://manual.raycast.com/custom-themes)
- [ray.so/themes: Theme Explorer](https://ray.so/themes)
- [SwiftUI Design Tokens & Theming System (Production-Scale) — DEV Community](https://dev.to/sebastienlato/swiftui-design-tokens-theming-system-production-scale-b16)
- [SwiftUI Design System: Semantic Colors — magnuskahr](https://www.magnuskahr.dk/posts/2025/06/swiftui-design-system-considerations-semantic-colors/)
- [Vibrancy, NSAppearance, and Visual Effects in Modern AppKit/SwiftUI — philz.blog](https://philz.blog/vibrancy-nsappearance-and-visual-effects-in-modern-appkit-apps/)
