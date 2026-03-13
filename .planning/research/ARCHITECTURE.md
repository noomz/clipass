# Architecture Research: v2.0 Overlay UI & Theming

**Project:** clipass
**Researched:** 2026-03-13
**Scope:** Overlay UI panel, Raycast-style theming, inline text editor — integration with existing SwiftUI/MenuBarExtra architecture
**Confidence:** HIGH (codebase analysis + verified patterns)

---

## Executive Summary

v2.0 introduces three features that each require a different integration strategy. The overlay panel requires the biggest architectural addition: a new NSPanel-based window managed outside SwiftUI's scene system. Theming slots cleanly into the existing environment propagation pattern. Inline editing is contained entirely within the overlay — it does not touch the menu bar popup.

The existing codebase (8K lines, 50 files) provides a solid foundation. `AppServices` is the right place to own the panel and theme manager. `ClipboardItem` data model needs no changes — overlay and popup share the same SwiftData store.

Key finding: the overlay is NOT a SwiftUI `Window` scene. It is an `NSPanel` hosted manually, because SwiftUI `Window` scenes cannot be positioned freely, kept always-on-top, or shown/hidden without activating the app. This is the only viable path for a Raycast-style overlay on macOS.

---

## Existing Architecture (v1.1 Baseline)

```
clipassApp.swift
    └── AppServices (singleton, @MainActor)
            ├── modelContainer (SwiftData: 7 models)
            ├── clipboardMonitor  — 500ms NSPasteboard polling
            ├── transformEngine   — regex transform rules
            └── hookEngine        — shell command hooks

Scenes (in clipassApp.body):
    ├── MenuBarExtra (.window style)
    │       └── ClipboardPopup  — @Query ClipboardItem, shows HistoryItemRow list
    └── Window("Settings", id: "settings")
            └── SettingsView    — sidebarAdaptable TabView (6 tabs)

Views/
    ├── ClipboardPopup.swift       — 300×350 popup, search, item list
    ├── HistoryItemRow.swift       — row with context menu, DisplayFormatter
    └── Settings tabs...

Services/
    ├── ClipboardMonitor.swift     — polling, filtering, transform dispatch
    ├── TransformEngine.swift      — applies TransformRule models
    ├── HookEngine.swift           — executes Hook models (shell)
    ├── ContentAnalyzer.swift      — regex-based content type detection
    ├── ContextActionEngine.swift  — matches + executes ContextAction
    └── DisplayFormatter.swift     — format/redact for preview display

KeyboardShortcuts.Name:
    └── .toggleClipboard           — Cmd+Shift+V (user-customizable)
```

---

## New Architecture (v2.0)

```
clipassApp.swift
    └── AppServices (singleton, @MainActor)
            ├── modelContainer (SwiftData: unchanged)
            ├── clipboardMonitor           — unchanged
            ├── transformEngine            — unchanged
            ├── hookEngine                 — unchanged
            ├── overlayWindowController    — NEW: owns the NSPanel lifecycle
            └── themeManager               — NEW: holds active Theme, persists selection

Scenes (in clipassApp.body):
    ├── MenuBarExtra (.window style)    — unchanged
    └── Window("Settings", id: "settings")
            └── SettingsView            — add Appearance tab for theme picker

NSPanel (managed by OverlayWindowController, NOT a Scene):
    └── ClipboardOverlayView            — NEW: full overlay UI
            ├── search bar (focused on show)
            ├── item list (OverlayItemRow)
            │       └── inline edit (conditional TextEditor, per row)
            └── themed with ThemeManager via .environment()

New files:
    Services/
        └── OverlayWindowController.swift  — NSPanel lifecycle, show/hide logic

    Models/
        └── Theme.swift                    — Theme struct + predefined themes

    Views/
        ├── ClipboardOverlayView.swift     — root overlay view (replaces ClipboardPopup in overlay context)
        ├── OverlayItemRow.swift           — row with inline edit toggle
        └── AppearanceSettingsView.swift   — theme picker in Settings

Modified:
    clipassApp.swift         — register OverlayWindowController, add .toggleOverlay shortcut
    SettingsView.swift       — add Appearance tab
```

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `OverlayWindowController` | Create/own the NSPanel, show/hide on shortcut, position on screen | AppServices (owns instance), KeyboardShortcuts |
| `ClipboardOverlayView` | Root SwiftUI view inside the panel, orchestrates search + list | SwiftData via @Query, ThemeManager via @Environment |
| `OverlayItemRow` | One clipboard item row in overlay — display + inline edit toggle | ClipboardItem (SwiftData model), ThemeManager |
| `ThemeManager` | Hold the active Theme, persist selection to UserDefaults, publish changes | Injected via @Observable into environment at NSPanel host site |
| `Theme` | Value type (struct) with all color/style tokens for one theme | ThemeManager reads, views consume via @Environment |
| `AppearanceSettingsView` | Theme picker UI in Settings | ThemeManager |

---

## Feature 1: Overlay Panel

### Design Decision: NSPanel, Not SwiftUI Window Scene

SwiftUI `Window` scenes on macOS have fixed constraints that disqualify them for a Raycast-style overlay:
- Cannot be kept above all other windows reliably (`level = .floating` requires AppKit)
- `NSApp.activate(ignoringOtherApps: true)` must be called to show them, which disrupts the frontmost app
- Cannot be shown/dismissed without appearing in the Dock and app switcher
- Fixed position behavior does not support center-screen overlay

The correct approach is an `NSPanel` subclass with `isFloatingPanel = true` and `styleMask` containing `.nonactivatingPanel`. This is the same mechanism used by Raycast, Alfred, Spotlight, and other launcher apps.

HIGH confidence — verified against Apple NSPanel documentation and multiple well-maintained open source examples (Sindre Sorhus pattern, Cindori floating panel guide).

### NSPanel Configuration

```swift
// OverlayWindowController.swift
final class OverlayWindowController: NSObject {
    private var panel: FloatingPanel?

    func show() {
        if panel == nil { panel = makePanel() }
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ClipboardOverlayView()
            .environment(ThemeManager.shared)
            .modelContext(AppServices.shared.modelContainer.mainContext))
        return panel
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

### Global Shortcut Integration

A second `KeyboardShortcuts.Name` is registered alongside `.toggleClipboard`:

```swift
// clipassApp.swift additions
extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
    static let toggleOverlay   = Self("toggleOverlay",   default: .init(.space, modifiers: [.command, .shift]))
}
```

In `AppServices.initialize()`, register the overlay shortcut next to the existing one:

```swift
KeyboardShortcuts.onKeyUp(for: .toggleOverlay) { [weak self] in
    self?.overlayWindowController.toggle()
}
```

The overlay shortcut must also be exposed in Settings `GeneralSettingsView` using `KeyboardShortcuts.Recorder`.

### Dismiss Behavior

The panel should dismiss on:
- Second press of the overlay shortcut (toggle)
- Escape key (handled in `ClipboardOverlayView` via `onKeyPress`)
- Clicking outside (handled by setting `panel.hidesOnDeactivate = false` and using `NSEvent` monitoring for clicks outside the panel bounds)

Note: `hidesOnDeactivate = true` would dismiss on every app switch, which is too aggressive. Use a global `NSEvent` monitor for `.leftMouseDown` outside panel bounds instead.

---

## Feature 2: Raycast-Style Theming

### Theme as a Value Type

A `Theme` is a struct of named color and style tokens. Themes are predefined values (not stored in SwiftData — they are code constants). User selection is persisted to `UserDefaults` via `@AppStorage`.

```swift
// Theme.swift
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String

    // Background
    let panelBackground: Color
    let panelBackgroundMaterial: NSVisualEffectView.Material  // for blur

    // Text
    let primaryText: Color
    let secondaryText: Color
    let placeholderText: Color

    // Interactive
    let accentColor: Color
    let selectionBackground: Color
    let hoverBackground: Color

    // Borders and dividers
    let borderColor: Color
    let dividerColor: Color

    // Predefined themes
    static let dark = Theme(id: "dark", name: "Dark", ...)
    static let light = Theme(id: "light", name: "Light", ...)
    static let midnight = Theme(id: "midnight", name: "Midnight", ...)
    static let nord = Theme(id: "nord", name: "Nord", ...)

    static let all: [Theme] = [.dark, .light, .midnight, .nord]
    static let `default` = Theme.dark
}
```

### ThemeManager: Observable, Injected via Environment

```swift
// ThemeManager.swift
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var activeTheme: Theme = .dark {
        didSet { UserDefaults.standard.set(activeTheme.id, forKey: "activeThemeId") }
    }

    private init() {
        let savedId = UserDefaults.standard.string(forKey: "activeThemeId") ?? Theme.default.id
        activeTheme = Theme.all.first(where: { $0.id == savedId }) ?? Theme.default
    }
}
```

`ThemeManager.shared` is injected at the panel's root view via `.environment(themeManager)` and consumed in child views with `@Environment(ThemeManager.self) private var themeManager`.

### Blur Background

The Raycast aesthetic uses a blurred/translucent panel background. This requires `NSViewRepresentable` wrapping `NSVisualEffectView` — SwiftUI's built-in `Material` modifier does not work for `NSPanel` backgrounds.

```swift
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
```

Each `Theme` carries its `panelBackgroundMaterial` token (e.g., `.sidebar`, `.underWindowBackground`, `.hudWindow`). The overlay root view applies `VisualEffectBackground` as a `.background()` layer.

### Theme Integration with Settings

`AppearanceSettingsView` is a new tab in `SettingsView`. It reads `ThemeManager.shared` and renders a visual preview grid of available themes. Selecting one calls `themeManager.activeTheme = selectedTheme`.

`SettingsView` currently has 6 tabs. Adding "Appearance" makes 7. The `sidebarAdaptable` style accommodates this without layout changes.

---

## Feature 3: Inline Text Editor

### Scope: Overlay Only

The inline editor is intentionally scoped to the overlay (`ClipboardOverlayView` / `OverlayItemRow`). The `ClipboardPopup` (menu bar popup) is not modified. This keeps the popup fast and simple.

### Click-to-Edit Pattern

Each `OverlayItemRow` has a local `@State var isEditing: Bool = false` and `@State var editText: String = ""`. On click (or a dedicated "Edit" action), the row switches from display mode to edit mode by toggling `isEditing`.

```swift
struct OverlayItemRow: View {
    let item: ClipboardItem
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        if isEditing {
            TextEditor(text: $editText)
                .focused($editorFocused)
                .onAppear { editorFocused = true }
                .onSubmit { commitEdit() }
                // Escape to cancel
                .background(theme.selectionBackground)
        } else {
            displayRow
                .onTapGesture(count: 2) { enterEditMode() }  // double-click to edit
        }
    }

    private func enterEditMode() {
        editText = item.content
        isEditing = true
    }

    private func commitEdit() {
        if editText != item.content {
            item.content = editText
            try? modelContext.save()
        }
        isEditing = false
    }
}
```

### Save Semantics

Edits are committed directly back to `ClipboardItem.content` in SwiftData. Because the same `ModelContext` is shared between the overlay and the menu bar popup (both receive `AppServices.shared.modelContainer.mainContext`), changes in the overlay immediately reflect in the popup's `@Query` without any additional synchronization.

### Focus on Show

When the overlay opens, the search bar should receive focus automatically. This requires `@FocusState` in `ClipboardOverlayView` and setting focus in `.onAppear`. The search text field focus is cleared by the edit row's focus steal when editing begins — no manual coordination needed.

---

## Data Flow Changes

### Before (v1.1)

```
[Global shortcut .toggleClipboard]
    → NSApp.activate()
    → MenuBarExtra panel opens
    → ClipboardPopup renders via @Query
```

### After (v2.0)

```
[Global shortcut .toggleClipboard]   — unchanged
    → NSApp.activate()
    → MenuBarExtra panel opens

[Global shortcut .toggleOverlay]     — NEW
    → OverlayWindowController.toggle()
    → NSPanel show/hide (no app activation, no Dock change)
    → ClipboardOverlayView renders via @Query (same ModelContext)
    → ThemeManager.activeTheme applied via @Environment

[Inline edit in overlay]             — NEW
    → OverlayItemRow.isEditing = true
    → TextEditor bound to local editText
    → On commit: item.content = editText; modelContext.save()
    → @Query in ClipboardPopup auto-updates (shared context)

[Theme selection in Settings]        — NEW
    → AppearanceSettingsView sets themeManager.activeTheme
    → ThemeManager persists to UserDefaults
    → @Observable propagation re-renders ClipboardOverlayView
```

---

## Build Order

Dependencies drive ordering: NSPanel must exist before theming can be tested visually; theming must be structurally in place before overlay views are styled; inline editing is the last row-level detail.

### Stage 1: NSPanel Foundation
**Goal:** Overlay panel appears on screen, dismisses, keyboard shortcut works.

1. Create `FloatingPanel` (NSPanel subclass) and `OverlayWindowController`
2. Add `.toggleOverlay` `KeyboardShortcuts.Name`
3. Wire `OverlayWindowController` into `AppServices.initialize()`
4. Create stub `ClipboardOverlayView` (plain list, no theming yet)
5. Add `KeyboardShortcuts.Recorder` for overlay shortcut to `GeneralSettingsView`

**Why first:** Everything else depends on the panel existing and showing the correct view.

### Stage 2: Theme System
**Goal:** Theme tokens defined, active theme propagated, overlay visually styled.

1. Create `Theme.swift` with struct and all predefined themes
2. Create `ThemeManager.swift` (@Observable, UserDefaults persistence)
3. Create `VisualEffectBackground` NSViewRepresentable
4. Inject `ThemeManager.shared` into panel's root view `.environment()`
5. Apply theme tokens to `ClipboardOverlayView` (backgrounds, text colors, blur)
6. Create `AppearanceSettingsView` — theme picker grid
7. Add Appearance tab to `SettingsView`

**Why second:** Visual correctness of the overlay depends on theming; inline editor UX also uses theme selection/hover colors.

### Stage 3: Overlay Item Rows
**Goal:** Overlay item list works end-to-end: search, select, copy, context actions.

1. Create `OverlayItemRow` — display mode only (reuse `HistoryItemRow` logic, themed)
2. Wire `@Query ClipboardItem` in `ClipboardOverlayView`
3. Implement search filtering (same logic as `ClipboardPopup`)
4. Keyboard navigation (up/down arrows, Enter to copy)
5. Escape to dismiss panel

**Why third:** Establishes the full overlay interaction loop before adding editing complexity.

### Stage 4: Inline Editor
**Goal:** Double-click item to edit text; Save updates ClipboardItem in SwiftData.

1. Add `isEditing` / `editText` state to `OverlayItemRow`
2. Add `TextEditor` edit mode branch with `@FocusState`
3. Commit on `onSubmit` / Escape to cancel without saving
4. Verify SwiftData round-trip (edit reflects in popup without restart)

**Why last:** Depends on all prior work; isolated to a single view.

---

## Integration Points Summary

| Existing File | Change Type | Change |
|---------------|-------------|--------|
| `clipassApp.swift` | Modified | Add `overlayWindowController` to `AppServices`; add `.toggleOverlay` shortcut in `initialize()`; inject `ThemeManager` into panel |
| `SettingsView.swift` | Modified | Add Appearance tab (7th tab) |
| `GeneralSettingsView` (inside SettingsView.swift) | Modified | Add `KeyboardShortcuts.Recorder` for `.toggleOverlay` |

| New File | Purpose |
|----------|---------|
| `Services/OverlayWindowController.swift` | NSPanel lifecycle, show/hide, toggle |
| `Models/Theme.swift` | Theme value type, all predefined themes, all color tokens |
| `Services/ThemeManager.swift` | Observable theme state, UserDefaults persistence |
| `Views/ClipboardOverlayView.swift` | Root view inside the NSPanel |
| `Views/OverlayItemRow.swift` | Item row with display + inline edit modes |
| `Views/AppearanceSettingsView.swift` | Theme picker in Settings |
| `Views/VisualEffectBackground.swift` | NSViewRepresentable for blur/vibrancy |

**Total new files: 7. Modified files: 3. Data model changes: none.**

---

## Patterns to Follow

### Pattern: @Observable ThemeManager in NSPanel

The NSPanel is not a SwiftUI `Scene`. Its content view is created with `NSHostingView(rootView:)`. Inject `ThemeManager` at that call site:

```swift
// In makePanel()
let rootView = ClipboardOverlayView()
    .environment(themeManager)  // @Observable object — direct injection
    .modelContext(AppServices.shared.modelContainer.mainContext)
panel.contentView = NSHostingView(rootView: rootView)
```

Consume in any descendant:
```swift
@Environment(ThemeManager.self) private var themeManager
```

This is the correct pattern for `@Observable` objects in SwiftUI — do NOT wrap in `ObservableObject`/`@EnvironmentObject`.

### Pattern: Shared ModelContext in Panel

The overlay and the menu bar popup share the exact same `ModelContext`. Pass it via `.modelContext()` at the panel's root — same as `ClipboardPopup` receives it today. SwiftData handles cross-context synchronization automatically.

### Pattern: Two-State Row (Display/Edit)

```swift
// OverlayItemRow: single source of truth in @State
if isEditing { TextEditor(...) } else { displayContent }
```

No shared editing state needed at the parent level — each row manages its own edit state independently. Only one row is ever in edit mode at a time because clicking into a TextEditor dismisses other rows naturally via focus transfer.

---

## Anti-Patterns to Avoid

### Anti-Pattern: SwiftUI Window Scene for Overlay
**What:** Adding a second `Window` scene to `clipassApp.body` for the overlay.
**Why bad:** SwiftUI Window scenes activate the app on show (`NSApp.activate()` is called), appear in the Dock during display, cannot maintain `.floating` window level, and cannot be centered programmatically without hacks.
**Instead:** Use `NSPanel` managed by `OverlayWindowController` as described above.

### Anti-Pattern: Separate ModelContainer for Overlay
**What:** Creating a second `ModelContainer` in the overlay window controller.
**Why bad:** Two containers create two independent SQLite stores — edits in overlay do not propagate to popup, duplicate data risk, migration complexity.
**Instead:** Pass `AppServices.shared.modelContainer.mainContext` to the overlay root view.

### Anti-Pattern: Storing Theme as SwiftData Model
**What:** Persisting `Theme` (or theme tokens) in SwiftData with a singleton pattern.
**Why bad:** Themes are code constants, not user data. SwiftData is for user-generated data. Schema migrations for theme changes are unnecessary friction. UserDefaults is the correct tool for a small string (theme ID).
**Instead:** Store only the selected theme ID in `UserDefaults`. Theme structs live in code.

### Anti-Pattern: Theming via Global @AppStorage
**What:** Using `@AppStorage("activeThemeId")` directly in views to read the theme.
**Why bad:** Every view that reads the key re-evaluates independently; there is no single source of truth; derived values (e.g., computed colors) are recomputed everywhere.
**Instead:** Use `ThemeManager` as the single consumer of `UserDefaults` and the single publisher of the active `Theme` object.

### Anti-Pattern: ClipboardMonitor Changes for Overlay
**What:** Modifying `ClipboardMonitor` to be overlay-aware, adding callbacks to the overlay.
**Why bad:** The monitor's job is capture and storage. Overlay display is a view concern. Adding UI callbacks to a service breaks separation of concerns.
**Instead:** `ClipboardOverlayView` uses `@Query` just like `ClipboardPopup`. No monitor changes needed.

---

## Scalability Considerations

| Concern | Now | Future |
|---------|-----|--------|
| Theme tokens | 6-8 color tokens per theme | Add `cornerRadius`, `fontSize`, `spacing` tokens as needed without structural change |
| Number of themes | 4 predefined | Add to `Theme.all` array — no architectural change |
| Custom user themes | Not in v2.0 | Would require persisting Theme as JSON in UserDefaults or a new SwiftData model |
| Overlay window per Space | Single panel (moves with user) | `collectionBehavior = .canJoinAllSpaces` handles this by default |
| Performance: overlay with 1000 items | `LazyVStack` + search filter | Same approach as popup; add virtualization if scrolling stutters |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| NSPanel and MenuBarExtra conflict (both responding to same shortcut) | Low | Medium | Use separate `KeyboardShortcuts.Name` values; `.toggleClipboard` remains unchanged |
| `NSHostingView` leaking memory when panel is recreated | Low | Medium | Create panel once, cache in `OverlayWindowController`; never recreate |
| `@FocusState` not working in NSPanel-hosted SwiftUI | Medium | Low | Fallback: use `NSApp.keyWindow?.makeFirstResponder()` via `NSViewRepresentable` wrapper |
| Theme change not re-rendering NSPanel content | Low | High | @Observable guarantees re-render when `activeTheme` changes; verify on first integration |
| Inline edit: save on window dismiss, user loses work | Medium | Low | Commit on every edit keystroke (bind `item.content` directly) or prompt on dismiss |
| NSPanel covering full-screen spaces incorrectly | Low | Medium | Set `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` |

---

## Sources

- Direct codebase analysis: clipass v1.1 (50 Swift files, 8014 lines)
- [NSPanel — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nspanel)
- [NSVisualEffectView — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsvisualeffectview)
- [Make a floating panel in SwiftUI for macOS — Cindori](https://cindori.com/developer/floating-panel) (NSPanel + SwiftUI hosting pattern)
- [Create a Spotlight/Alfred like window on macOS with SwiftUI — Markus Bodner](https://www.markusbodner.com/til/2021/02/08/create-a-spotlight/alfred-like-window-on-macos-with-swiftui/)
- [Making macOS SwiftUI text views editable on click — Pol Piella](https://www.polpiella.dev/swiftui-editable-list-text-items)
- [EnvironmentValues — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/environmentvalues)
- [Raycast Custom Themes — Raycast Manual](https://manual.raycast.com/custom-themes)
- [Direct and reflect focus in SwiftUI — WWDC21](https://developer.apple.com/videos/play/wwdc2021/10023/)
- [The SwiftUI cookbook for focus — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10162/)

---

**Confidence:** HIGH — NSPanel pattern is well-documented and battle-tested in macOS launcher apps. SwiftUI integration points are verified against Apple documentation. All integration points derived from direct codebase reading, not assumptions.
