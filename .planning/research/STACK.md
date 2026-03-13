# Stack Research: v2.0 Overlay UI & Theming

**Project:** clipass v2.0
**Researched:** 2026-03-13
**Focus:** Stack additions for overlay panel, Raycast-style theming, and inline text editor

## Executive Summary

v2.0 requires **zero new Swift Package dependencies**. All three new features — floating overlay panel, theme system, and inline text editor — are buildable with existing stack (AppKit/SwiftUI bridging already used, `@FocusState` is built-in, SwiftUI Environment theming is native). The overlay window uses a raw `NSPanel` subclass, theming uses a custom `@Observable` class injected via Environment, and inline editing uses `TextEditor` with `@FocusState`. The only addition to `KeyboardShortcuts` is registering a second shortcut name — same library, already a dependency.

## New Dependencies

**None required.**

All capabilities needed are available in the existing stack or via AppKit bridging patterns already in use.

## Existing Stack Extensions

### 1. NSPanel Subclass — Overlay Window

The overlay panel cannot use SwiftUI's `Window` scene or `MenuBarExtra` — both have constraints (activation behavior, positioning) that break the Raycast-style experience. The solution is a raw `NSPanel` subclass bridged to SwiftUI via `NSViewControllerRepresentable` hosting.

**Why NSPanel over NSWindow:**
- `NSPanel` supports `.nonactivatingPanel` style mask — panel shows without stealing focus from the frontmost app
- Appropriate for palette/utility windows that float above normal windows
- `animationBehavior = .utilityWindow` gives the fast pop-in/pop-out feel

**Key NSPanel configuration:**

```swift
final class OverlayPanel: NSPanel {
    init<Content: View>(@ViewBuilder content: () -> Content) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        contentViewController = NSHostingController(rootView: content())
    }
}
```

**Show/hide pattern:**

```swift
// Show: position near screen center (or last position), then order front
panel.setFrameOriginToScreenCenter()
panel.orderFrontRegardless()

// Hide: close or orderOut
panel.orderOut(nil)
```

**Activation via KeyboardShortcuts:** The existing `KeyboardShortcuts` library handles the global shortcut. Register a second name alongside the existing `toggleClipboard`:

```swift
extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
    static let toggleOverlay = Self("toggleOverlay", default: .init(.space, modifiers: [.command, .shift]))
}
```

No library upgrade needed. `KeyboardShortcuts` is already at `from: "2.0.0"` (latest: 2.4.0). The `onKeyUp` API handles multiple names independently.

**Visual material (background blur):**

`NSVisualEffectView` via `NSViewRepresentable` provides the frosted glass background. This works on macOS 14 (clipass minimum target). The newer `.glassEffect` modifier is macOS 26 only — do not use it.

```swift
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
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

**Confidence:** HIGH (NSPanel pattern is well-documented, AppKit is stable, NSVisualEffectView confirmed for macOS 14+)

---

### 2. Theme System — SwiftUI Environment + @Observable

No library needed. SwiftUI's Environment injection and `@Observable` (macOS 14+) handle the full theme system.

**Pattern:** Define a `ThemeDefinition` struct with all color tokens. Store the active theme name in `@AppStorage`. Inject a computed `AppTheme` observable into the view hierarchy via a custom `EnvironmentKey`.

**Why this approach over alternatives:**
- `@Observable` + `EnvironmentObject` propagates changes automatically — every view that reads `@Environment(\.appTheme)` updates when theme switches
- `@AppStorage("activeTheme")` persists selection across launches without SwiftData overhead
- No extra dependency (vs. third-party theme libraries)
- Predefined themes are just static `ThemeDefinition` instances — adding new themes requires zero architecture change

**Core types:**

```swift
struct ThemeDefinition: Identifiable, Codable {
    let id: String           // e.g. "raycast-dark"
    let name: String         // e.g. "Raycast Dark"
    var background: Color
    var surface: Color       // item row background
    var surfaceHover: Color
    var text: Color
    var textSecondary: Color
    var accent: Color        // selection, buttons
    var border: Color
    var searchBarBackground: Color
}

@Observable
final class AppTheme {
    var current: ThemeDefinition

    static let predefined: [ThemeDefinition] = [
        .raycastDark,
        .raycastLight,
        .midnight,
        .solarizedDark,
    ]
}
```

**Environment injection (macOS 14+ @Entry macro):**

```swift
extension EnvironmentValues {
    @Entry var appTheme: AppTheme = AppTheme()
}
```

Apply at overlay root view: `.environment(\.appTheme, services.appTheme)`

**Color scheme interaction:** Themes are independent of system dark/light mode. The overlay forces its own color scheme via `.preferredColorScheme(.dark)` or `.light` based on the theme's declared appearance. This prevents the system from overriding theme colors.

**UserDefaults key:** `"activeThemeId"` — persists the selected theme ID across launches.

**Confidence:** HIGH (`@Observable` verified available macOS 14+, `@Entry` macro verified Xcode 16+/Swift 5.10+, `@AppStorage` is standard SwiftUI)

---

### 3. Inline Text Editor — TextEditor + @FocusState

No library needed. SwiftUI's `TextEditor` with `@FocusState` and a two-state (display/edit) toggle is the correct approach for macOS 14+.

**Pattern:** Each clipboard item row in the overlay has two rendering modes — display (read-only `Text`) and edit (`TextEditor`). A tap/click toggles the mode. `@FocusState` auto-focuses the editor when entering edit mode.

**Why TextEditor over TextField:**
- Clipboard items are multiline — `TextEditor` scrolls and wraps, `TextField` (even with `axis: .vertical`) has UX quirks on macOS
- Native undo/redo support comes for free
- Supports standard text editing keyboard shortcuts (Cmd+A, Cmd+Z, etc.)

**Core pattern:**

```swift
struct InlineEditableItem: View {
    @Binding var content: String
    @State private var editBuffer: String = ""
    @State private var isEditing = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextEditor(text: $editBuffer)
                    .focused($editorFocused)
                    .onAppear { editorFocused = true }
                    .onExitCommand { cancelEdit() }     // Escape cancels
                    .onSubmit { commitEdit() }           // Enter commits (if desired)
            } else {
                Text(content)
                    .onTapGesture(count: 2) { startEdit() }   // double-click to edit
            }
        }
    }

    private func startEdit() {
        editBuffer = content
        isEditing = true
    }

    private func commitEdit() {
        content = editBuffer
        isEditing = false
    }

    private func cancelEdit() {
        editBuffer = content
        isEditing = false
    }
}
```

**Commit triggers:**
- Click outside the editor (`.onChange(of: editorFocused)` — when focus lost, commit)
- Explicit "Save" button in the row toolbar
- Do NOT use Enter to commit (clipboard content can be multiline — Enter is content, not confirm)

**SwiftData write-back:** The `content` binding passes through to the `ClipboardItem.content` property. The existing SwiftData context handles persistence — no new model fields needed for editing.

**Confidence:** HIGH (TextEditor, FocusState, and onExitCommand are stable macOS 14+ SwiftUI APIs)

---

## Package.swift Changes

**No changes required.** The existing dependency block remains:

```swift
dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.0.0"),
],
```

Optionally upgrade KeyboardShortcuts constraint to `from: "2.4.0"` (latest as of 2025-09-18) to pick up bug fixes, but it is not required — the API used is stable across 2.x.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Overlay window | NSPanel subclass | SwiftUI `Window` scene | Window scene activates app, cannot `.nonactivatingPanel` |
| Overlay window | NSPanel subclass | Third-party (Luminare, etc.) | Adds a dependency for a well-understood 30-line pattern |
| Visual background | NSVisualEffectView bridge | `.glassEffect` | macOS 26 only; clipass targets macOS 14 |
| Theme system | @Observable + Environment | Third-party theme library | Zero-dependency native solution is sufficient for a color token system |
| Theme persistence | @AppStorage (string ID) | SwiftData | No user-created list; fixed set of predefined + one custom. @AppStorage is sufficient |
| Inline editor | TextEditor + @FocusState | NSTextView bridge | NSTextView bridge adds AppKit complexity; TextEditor is sufficient for plain text |
| Second shortcut | New KeyboardShortcuts.Name | Separate shortcut manager | Same library already in project; registering a second name is trivial |

---

## Integration Points

| v2.0 Feature | Stack Component | Mechanism | New/Existing |
|--------------|-----------------|-----------|--------------|
| Overlay panel window | NSPanel subclass | AppKit + NSHostingController | New (no dependency) |
| Overlay show/hide | KeyboardShortcuts `.toggleOverlay` | New `Name` in existing lib | Existing library |
| Frosted glass background | NSVisualEffectView bridge | NSViewRepresentable | New (no dependency) |
| Theme tokens | `AppTheme` + `ThemeDefinition` | @Observable + Environment | New (no dependency) |
| Theme persistence | @AppStorage | "activeThemeId" UserDefaults key | Existing pattern |
| Click-to-edit | TextEditor + @FocusState | SwiftUI state toggling | New (no dependency) |
| Edit persistence | SwiftData `ClipboardItem.content` | Existing model field | Existing model |

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| NSPanel overlay pattern | HIGH | Well-established macOS pattern, confirmed working in production apps (Alfred, Raycast, many utilities) |
| KeyboardShortcuts multi-shortcut | HIGH | Verified in README — multiple `Name` declarations are the documented pattern |
| NSVisualEffectView bridge | HIGH | Standard AppKit API, macOS 14+, used broadly |
| @Observable theme system | HIGH | @Observable available macOS 14+ (clipass minimum), @Entry macro Xcode 16+/Swift 5.10+ |
| TextEditor inline editing | HIGH | Stable SwiftUI APIs, FocusState confirmed macOS 14+ |
| No new dependencies needed | HIGH | Each feature has a clear native/AppKit path with zero external libraries |

---

## Sources

- NSPanel nonactivatingPanel: https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
- Floating panel SwiftUI pattern: https://cindori.com/developer/floating-panel
- Spotlight-like window: https://www.markusbodner.com/til/2021/02/08/create-a-spotlight/alfred-like-window-on-macos-with-swiftui/
- KeyboardShortcuts (v2.4.0, latest): https://github.com/sindresorhus/KeyboardShortcuts/releases
- @Entry macro custom environment values: https://www.avanderlee.com/swiftui/entry-macro-custom-environment-values/
- TextEditor SwiftUI: https://developer.apple.com/documentation/swiftui/texteditor
- Editable list text items macOS: https://www.polpiella.dev/swiftui-editable-list-text-items
- NSVisualEffectView for macOS 14: https://onmyway133.com/posts/how-to-make-visual-effect-blur-in-swiftui-for-macos/
- glassEffect macOS 26 limitation: https://www.klaritydisk.com/blog/building-liquid-glass-ui-macos
