# Phase 12: Overlay Panel - Research

**Researched:** 2026-03-13
**Domain:** macOS NSPanel, SwiftUI hosting, vibrancy/blur, keyboard navigation, focus management
**Confidence:** HIGH

## Summary

Phase 12 builds a Raycast/Spotlight-style floating overlay panel for clipass. The panel must appear above all other windows without activating the app (non-activating NSPanel), display frosted glass vibrancy, auto-focus a search field, support arrow-key navigation and Return-to-paste, and dismiss with ESC or click-outside while returning focus to the previous app. A separate configurable global hotkey toggles it open/closed.

The confirmed architecture decision (STATE.md) is **NSPanel subclass — not a SwiftUI Window scene**. This is mandatory. SwiftUI Window/MenuBarExtra cannot produce non-activating floating behavior. The NSPanel hosts a `NSHostingView<SwiftUI.View>` for all UI content.

The key non-obvious challenge is the **paste-and-restore pattern**: on Return key, the panel must (1) write the selected item to NSPasteboard, (2) hide the panel, (3) reactivate the *previously frontmost app*, and (4) optionally simulate Cmd+V. Step 4 requires Accessibility entitlement/permission (`CGEventPost` to `kCGSessionEventTap`); step 3 uses `NSWorkspace.shared.frontmostApplication` captured *before* the panel is shown.

**Primary recommendation:** Subclass NSPanel with `[.nonactivatingPanel, .titled, .fullSizeContentView]` style mask, override `canBecomeKey`/`canBecomeMain` to `true`, host SwiftUI via `NSHostingView`, capture `NSWorkspace.shared.frontmostApplication` before show, restore on dismiss/Return.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| OVRL-01 | User can summon a floating overlay panel via a dedicated global hotkey | New `KeyboardShortcuts.Name.toggleOverlay`; `OverlayWindowController.shared.toggle()` |
| OVRL-02 | User can dismiss the overlay with ESC key | `.onKeyPress(.escape)` or `keyDown` override in NSPanel; calls `hide()` |
| OVRL-03 | User can dismiss the overlay by clicking outside the panel | Override `resignKey()` in NSPanel subclass to call `close()`/`orderOut` |
| OVRL-04 | Same hotkey toggles overlay open/closed | `toggle()` checks `isVisible` before show/hide |
| OVRL-05 | Search field is auto-focused when overlay opens | `DispatchQueue.main.asyncAfter(0.1)` to set `@FocusState` or `makeFirstResponder` fallback |
| OVRL-06 | User can navigate clipboard items with arrow keys and paste with Return | SwiftUI `List` with `selection:` binding + `.onKeyPress(.return)` action |
| OVRL-07 | Overlay displays frosted glass vibrancy background | `NSViewRepresentable` wrapping `NSVisualEffectView` with `.behindWindow` blending |
| OVRL-08 | Overlay shows/hides with smooth animation | SwiftUI `.transition(.opacity.combined(with: .scale))` inside `withAnimation` |
| OVRL-09 | User can configure the overlay hotkey in Settings | `KeyboardShortcuts.Recorder("Toggle Overlay:", name: .toggleOverlay)` in GeneralSettingsView |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AppKit `NSPanel` | macOS 14+ (built-in) | Non-activating floating window host | Only window type that supports floating above all apps without activating them |
| SwiftUI `NSHostingView` | macOS 14+ (built-in) | Embed SwiftUI content inside NSPanel | Bridge between AppKit panel and SwiftUI layout/state |
| `KeyboardShortcuts` (sindresorhus) | 2.4.0 (already in project) | User-configurable global hotkey for overlay | Already used for `toggleClipboard`; supports multiple named shortcuts |
| `NSVisualEffectView` | macOS 14+ (built-in) | Frosted glass / vibrancy background | Apple-native blur; only way to get true behind-window blur on macOS |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `CGEventPost` | macOS 14+ (built-in) | Simulate Cmd+V to paste to previous app | Only if auto-paste on Return is desired; requires Accessibility permission — use as opt-in |
| `NSWorkspace.shared.frontmostApplication` | macOS 14+ (built-in) | Capture previous app before overlay opens | Called once at `show()` time; stored as `previousApp` for restore on dismiss |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSPanel subclass | SwiftUI Window scene | Window scenes always activate the app, break non-activating requirement — ruled out |
| NSPanel subclass | NSPopover | Popovers must be anchored to a view; can't be summoned by global hotkey from nowhere |
| NSHostingView | Pure AppKit UI | SwiftUI is the project's entire UI layer; mixing raw AppKit views adds massive maintenance cost |
| `NSViewRepresentable` for vibrancy | `.background(.ultraThinMaterial)` SwiftUI modifier | SwiftUI `.ultraThinMaterial` only works on macOS with `.regular` activation policy; fails under `.accessory` policy; NSViewRepresentable is reliable |

**Installation:** No new packages needed. All dependencies already exist in `Package.swift`.

## Architecture Patterns

### Recommended Project Structure
```
clipass/
├── clipassApp.swift               # Add .toggleOverlay shortcut + OverlayWindowController init
├── Controllers/
│   └── OverlayWindowController.swift  # NSPanel subclass controller (show/hide/toggle)
└── Views/
    ├── ClipboardOverlayView.swift      # Root SwiftUI view for the panel
    ├── OverlayItemRow.swift            # Row view with keyboard selection highlighting
    └── VisualEffectView.swift          # NSViewRepresentable for NSVisualEffectView
```

### Pattern 1: NSPanel Subclass (Non-Activating Floating Panel)

**What:** Subclass `NSPanel` with style mask and properties that keep the panel floating above all windows without stealing app activation from the previous frontmost app.

**When to use:** Any macOS overlay that must remain above other windows and accept keyboard input without becoming the active application.

**Example:**
```swift
// Source: https://cindori.com/developer/floating-panel
// Source: https://philz.blog/nspanel-nonactivating-style-mask-flag/
final class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [
                .nonactivatingPanel,
                .titled,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        // Floating behaviors
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Allow key input (text field focus) without activating the app
        // canBecomeKey MUST return true — NSPanel default is false
        // canBecomeMain should also be true for @FocusState to work

        // Visual
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    // CRITICAL: Must override both — NSPanel defaults canBecomeKey to false
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Click-outside dismissal (OVRL-03)
    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }
}
```

### Pattern 2: OverlayWindowController (Show/Hide/Toggle)

**What:** A singleton controller that owns the `OverlayPanel`, captures the previous frontmost app, and manages show/hide lifecycle with focus restoration.

**When to use:** Centralizes all panel lifecycle; called from global hotkey handler and from overlay view's ESC/Return actions.

**Example:**
```swift
@MainActor
final class OverlayWindowController {
    static let shared = OverlayWindowController()

    private let panel: OverlayPanel
    private var previousApp: NSRunningApplication?

    private init() {
        panel = OverlayPanel()
        // Inject SwiftUI content
        let contentView = ClipboardOverlayView()
        panel.contentView = NSHostingView(rootView: contentView)
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        // Capture BEFORE making panel key (panel is non-activating so frontmost won't change)
        previousApp = NSWorkspace.shared.frontmostApplication
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        // @FocusState may not fire reliably in NSPanel — post delayed fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let contentView = self.panel.contentView {
                self.panel.makeFirstResponder(contentView)
            }
        }
    }

    func hide() {
        panel.orderOut(nil)
        // Restore previous app focus
        previousApp?.activate(options: .activateIgnoringOtherApps)
        previousApp = nil
    }

    // Called by Return key — paste then hide
    func pasteAndHide(content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        hide()
        // Optionally simulate Cmd+V (requires Accessibility permission)
        // simulatePaste()
    }
}
```

### Pattern 3: NSVisualEffectView via NSViewRepresentable (OVRL-07)

**What:** Wrap `NSVisualEffectView` in `NSViewRepresentable` for use as a SwiftUI background. The `.background(.ultraThinMaterial)` SwiftUI modifier is unreliable under `.accessory` activation policy — the `NSViewRepresentable` approach is reliable.

**When to use:** Any frosted glass background in a panel or accessory-policy app.

**Example:**
```swift
// Source: https://0xffa4.com/posts/4
// Source: Apple Developer Docs NSVisualEffectView
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active  // CRITICAL: must be .active for accessory policy apps
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Usage in ClipboardOverlayView:
var body: some View {
    ZStack {
        VisualEffectView()  // Full-bleed background
        content
    }
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

### Pattern 4: Search + List Keyboard Navigation (OVRL-05, OVRL-06)

**What:** Search `TextField` auto-focused on open; SwiftUI `List` with `selection:` binding for highlight; `onKeyPress` handles `.return` for paste, arrow keys optionally override list built-in navigation.

**When to use:** Any keyboard-first item picker in a panel.

**Example:**
```swift
// Source: Apple Developer Docs onKeyPress, WWDC23 Focus cookbook
struct ClipboardOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @State private var searchText = ""
    @State private var selectedID: ClipboardItem.ID?
    @FocusState private var searchFocused: Bool

    private var filteredItems: [ClipboardItem] { /* same as ClipboardPopup */ }

    var body: some View {
        VStack(spacing: 0) {
            // Search field — auto-focused via .focused binding
            TextField("Search clipboard...", text: $searchText)
                .focused($searchFocused)
                .onAppear { searchFocused = true }  // may need asyncAfter fallback
                .padding()

            Divider()

            List(filteredItems, selection: $selectedID) { item in
                OverlayItemRow(item: item)
                    .tag(item.id)
            }
            // Return key: paste selected item and hide
            .onKeyPress(.return) {
                if let id = selectedID,
                   let item = filteredItems.first(where: { $0.id == id }) {
                    OverlayWindowController.shared.pasteAndHide(content: item.content)
                }
                return .handled
            }
        }
        // ESC key: dismiss without pasting
        .onKeyPress(.escape) {
            OverlayWindowController.shared.hide()
            return .handled
        }
    }
}
```

### Pattern 5: Smooth Show/Hide Animation (OVRL-08)

**What:** Use SwiftUI transition on a top-level overlay state, or animate the NSPanel window alpha. The simplest approach is an `isVisible` Bool + `withAnimation` inside the SwiftUI view with `.opacity` + `.scale` transition.

**Example:**
```swift
// Apply to the root content inside the panel
ZStack {
    if showContent {
        overlayBody
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
.animation(.easeOut(duration: 0.15), value: showContent)
```

Alternatively, animate `panel.alphaValue` from AppKit side for panel enter/exit.

### Anti-Patterns to Avoid

- **SwiftUI Window scene for the overlay:** Window scenes always call `NSApp.activate()` which steals app focus — exactly what `.nonactivatingPanel` prevents. Never use `Window("Overlay", id:)` scene for this.
- **Setting `styleMask` after init:** The `nonactivatingPanel` bit does not correctly update the internal `kCGSPreventsActivationTagBit` window tag when changed post-init. Always set it in the `NSPanel.init()` call.
- **Calling `NSApp.activate()` before `show()`:** The existing `toggleClipboard` hotkey calls `NSApp.activate()`. The overlay hotkey must NOT do this — the whole point is to stay non-activating.
- **Relying on `.ultraThinMaterial` for vibrancy:** SwiftUI materials only work correctly under `.regular` activation policy. Under `.accessory` (menu bar apps), they render as solid colors. Use `NSViewRepresentable` + `NSVisualEffectView.state = .active` instead.
- **Using `@FocusState` as the only focus mechanism:** `@FocusState` is unreliable when a view first appears inside an NSPanel (the SwiftUI responder chain hasn't fully settled). Always add a `DispatchQueue.main.asyncAfter(0.1)` fallback calling `panel.makeFirstResponder(contentView)`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Global hotkey for overlay | Custom `NSEvent.addGlobalMonitorForEvents` listener | `KeyboardShortcuts` (already in project) | Handles system conflicts, UserDefaults persistence, Recorder UI — already proven in this codebase |
| Frosted glass background | Alpha-only SwiftUI background view | `NSVisualEffectView` via `NSViewRepresentable` | System-native blur that responds to window content behind it — impossible to replicate |
| User-configurable hotkey recorder | Custom key capture view | `KeyboardShortcuts.Recorder` | Already handles all edge cases (option key, modifier-only, conflict detection) |
| Keyboard shortcut definition | Raw UserDefaults key codes | `KeyboardShortcuts.Name` extension | Strongly typed, persistent, works with Recorder automatically |

**Key insight:** The project already has `KeyboardShortcuts` 2.4.0 — adding a second named shortcut is 2 lines of code. Do not introduce a second hotkey library.

## Common Pitfalls

### Pitfall 1: NSApp.activate() in the Overlay Hotkey Handler
**What goes wrong:** The existing `toggleClipboard` shortcut calls `NSApp.activate(ignoringOtherApps: true)` in `clipassApp.swift`. If the same pattern is copied for the overlay hotkey, the overlay will steal app activation, making the "return focus to previous app" feature impossible.
**Why it happens:** The existing hotkey activates the app so the menu bar popup can receive keyboard events (MenuBarExtra does not need non-activating behavior). The overlay does — it uses a different mechanism.
**How to avoid:** In the `toggleOverlay` `onKeyUp` handler, call `OverlayWindowController.shared.toggle()` directly. Do NOT call `NSApp.activate()`.
**Warning signs:** After pressing the overlay hotkey, the Dock icon shows the app as active (bouncing), or the previously-focused app loses its cursor blink.

### Pitfall 2: FocusState Not Working in NSPanel
**What goes wrong:** The search `TextField` inside `ClipboardOverlayView` does not receive keyboard focus when the panel opens, even with `.focused($searchFocused)` and `searchFocused = true` in `.onAppear`.
**Why it happens:** `@FocusState` requires the SwiftUI focus engine to settle after a view appears. In an NSPanel that just became key, there's a race between the panel gaining key status and SwiftUI setting up focus.
**How to avoid:** Add a delayed fallback:
```swift
.onAppear {
    searchFocused = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        panel.makeFirstResponder(panel.contentView)
    }
}
```
**Warning signs:** Panel opens but typing doesn't filter — text appears nowhere.

### Pitfall 3: Click-Outside Dismissal Firing at Wrong Time
**What goes wrong:** The panel closes immediately after opening because `resignKey()` fires during some initialization path.
**Why it happens:** `makeKeyAndOrderFront` can briefly assign key status to the panel, then another system panel (Accessibility prompt, Spotlight) transiently takes key — triggering `resignKey()`.
**How to avoid:** Add a brief guard window: set a `isShowing` flag in `show()` and only dismiss in `resignKey()` if `Date().timeIntervalSince(shownAt) > 0.2`.
**Warning signs:** Panel flashes briefly and immediately closes.

### Pitfall 4: NSVisualEffectView Not Blurring
**What goes wrong:** The vibrancy view renders as a flat gray instead of transparent + blurred backdrop.
**Why it happens:** Under `.accessory` activation policy, `NSVisualEffectView` defaults `state` to `.followsWindowActiveState`, which yields inactive appearance (no blur). Requires explicit `.active`.
**How to avoid:** Always set `view.state = .active` in `makeNSView`.
**Warning signs:** The overlay background matches the `NSColor.windowBackgroundColor` exactly — no content from behind the window shows through.

### Pitfall 5: Paste Lands in Wrong App
**What goes wrong:** After pressing Return, the paste goes into the overlay itself or into a random app instead of the previously-focused one.
**Why it happens:** `previousApp` was captured after `NSApp.activate()` was already called, meaning the "previous" app is clipass itself. Or `previousApp.activate()` hasn't completed before `CGEventPost` fires.
**How to avoid:** Capture `NSWorkspace.shared.frontmostApplication` synchronously in `show()` *before* any activation call. When using `CGEventPost` for auto-paste, add a small delay after `activate()`:
```swift
previousApp?.activate(options: .activateIgnoringOtherApps)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
    simulatePaste()
}
```
**Warning signs:** Paste content appears in the wrong text field, or not at all.

## Code Examples

### Defining the Second Shortcut Name
```swift
// Source: https://github.com/sindresorhus/KeyboardShortcuts
// In clipassApp.swift, alongside the existing .toggleClipboard:
extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
    static let toggleOverlay = Self("toggleOverlay")  // No default — user configures it
}
```

### Registering the Overlay Hotkey Handler
```swift
// In AppServices.initialize(), after existing hotkey:
KeyboardShortcuts.onKeyUp(for: .toggleOverlay) {
    // DO NOT call NSApp.activate() here
    OverlayWindowController.shared.toggle()
}
```

### Settings: Adding the Overlay Hotkey Recorder
```swift
// In GeneralSettingsView.body Form:
Section {
    KeyboardShortcuts.Recorder("Toggle Overlay:", name: .toggleOverlay)
} header: {
    Text("Overlay Hotkey")
}
```

### Centering the Panel on Screen
```swift
// Standard pattern — center on the screen that has the mouse
func show() {
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
        ?? NSScreen.main {
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.midY + screenFrame.height * 0.1  // Slightly above center
        )
        panel.setFrameOrigin(origin)
    }
    panel.makeKeyAndOrderFront(nil)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Pure AppKit NSMenu for clipboard overlays | SwiftUI + NSHostingView inside NSPanel (Maccy 2.0) | 2024 | Dramatically less code; SwiftData works directly |
| `NSEvent.addGlobalMonitorForEvents` for hotkeys | `KeyboardShortcuts` library | ~2020+ | Handles sandbox, conflicts, UserDefaults automatically |
| AppKit-only vibrancy setup | `NSViewRepresentable` wrapping `NSVisualEffectView` | ~2019+ | Clean SwiftUI integration |
| `onKeyDown` override in NSWindow | `.onKeyPress()` SwiftUI modifier (macOS 14+) | macOS 14 (2023) | Fully declarative; required for this project (minimum macOS 14) |

**Deprecated/outdated:**
- `NSEvent.addGlobalMonitorForEvents` for configurable shortcuts: replaced by KeyboardShortcuts library in this project
- Manual `NSView.becomeFirstResponder()` override for text focus: `@FocusState` + `makeFirstResponder` fallback is the current pattern

## Open Questions

1. **Auto-paste vs copy-only on Return**
   - What we know: `CGEventPost` can simulate Cmd+V but requires Accessibility permission prompt; the project is not distributed via App Store (spm-based, Developer ID distribution likely)
   - What's unclear: Does the user expect one-keystroke paste (like Raycast/Maccy) or copy-to-clipboard then manual paste?
   - Recommendation: Phase 12 implements copy-to-clipboard + hide (always works). Auto-paste via `CGEventPost` can be a configurable opt-in toggle in Settings, gated by Accessibility permission check.

2. **Panel position persistence**
   - What we know: Centering on screen-with-mouse on each show is standard for Spotlight-style launchers
   - What's unclear: Should position be remembered across invocations?
   - Recommendation: Don't persist position — the panel is ephemeral. Always re-center. REQUIREMENTS.md does not require position persistence.

3. **modelContext injection into NSPanel-hosted SwiftUI**
   - What we know: `AppServices.shared.modelContainer.mainContext` exists; can be passed via `.modelContext()` environment modifier on the root view passed to `NSHostingView`
   - What's unclear: Whether `@Query` inside `ClipboardOverlayView` will receive live updates
   - Recommendation: Pass context as `NSHostingView(rootView: view.modelContext(AppServices.shared.modelContainer.mainContext))` — same pattern as `ClipboardPopup`.

## Validation Architecture

> `workflow.nyquist_validation` is not set in config.json — treating as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected in project (no test targets in Package.swift) |
| Config file | None |
| Quick run command | `swift build` (compilation check only) |
| Full suite command | `swift build` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OVRL-01 | Overlay hotkey name defined and handler registered | manual-only | N/A — requires global hotkey system interaction | N/A |
| OVRL-02 | ESC dismisses overlay | manual-only | N/A — requires UI interaction | N/A |
| OVRL-03 | Click outside dismisses overlay | manual-only | N/A — requires UI interaction | N/A |
| OVRL-04 | Toggle behavior (open if closed, close if open) | unit (logic) | `swift build` then manual | N/A |
| OVRL-05 | Search field focuses on open | manual-only | N/A — requires focus system | N/A |
| OVRL-06 | Arrow keys navigate, Return pastes | manual-only | N/A — requires UI interaction | N/A |
| OVRL-07 | Vibrancy renders as frosted glass | manual-only | N/A — visual only | N/A |
| OVRL-08 | Smooth show/hide animation | manual-only | N/A — visual only | N/A |
| OVRL-09 | Overlay hotkey recorder in Settings | manual-only | N/A — requires UI | N/A |

> **Note:** This project has no automated test target. All validation is manual. The build (`swift build`) serves as the compilation gate.

### Sampling Rate
- **Per task commit:** `swift build` (compilation check)
- **Per wave merge:** `swift build` + manual smoke test of each OVRL requirement
- **Phase gate:** All 9 OVRL requirements pass manual checklist before `/gsd:verify-work`

### Wave 0 Gaps
None — no test infrastructure exists and project has no test target. Manual verification is the established pattern across all prior phases.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `NSPanel`, `NSVisualEffectView`, `NSWorkspace.frontmostApplication`, `NSWindow.canBecomeKey`, `.nonactivatingPanel` style mask
- Apple Developer Documentation: `onKeyPress(_:action:)` — confirmed available macOS 14+
- `KeyboardShortcuts` GitHub (sindresorhus/KeyboardShortcuts v2.4.0) — confirmed multi-shortcut support, `Recorder` SwiftUI component, `onKeyUp` handler
- Project source: `clipassApp.swift`, `SettingsView.swift`, `ClipboardPopup.swift` — existing patterns to follow

### Secondary (MEDIUM confidence)
- [Cindori: Make a floating panel in SwiftUI for macOS](https://cindori.com/developer/floating-panel) — NSPanel subclass full example, verified against Apple docs
- [philz.blog: The Curious Case of NSPanel's Nonactivating Style Mask Flag](https://philz.blog/nspanel-nonactivating-style-mask-flag/) — documents the post-init style mask bug + `_setPreventsActivation:` workaround
- [0xffa4.com: Adding Blur Effects to a macOS App using SwiftUI](https://0xffa4.com/posts/4) — NSViewRepresentable vibrancy pattern
- Maccy 2.0 rewrite (SwiftUI + NSPanel + SwiftData confirmed) — architecture validation that NSPanel + SwiftUI + SwiftData is the current standard for macOS clipboard managers

### Tertiary (LOW confidence)
- Multi.app blog post on activation behavior — page returned CSS/HTML only, could not extract content; general findings from other sources cover the same territory

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in project, documented Apple APIs
- Architecture: HIGH — NSPanel + SwiftUI pattern well-documented, used in Maccy 2.0, confirmed in project STATE.md decisions
- Pitfalls: HIGH — `@FocusState` unreliability in NSPanel, `.nonactivatingPanel` post-init bug, vibrancy under `.accessory` policy all independently confirmed by multiple sources
- Paste/focus restore: MEDIUM — `NSWorkspace.frontmostApplication` + `activate()` pattern is documented; `CGEventPost` behavior in non-sandboxed apps confirmed; exact timing needs in-app validation

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable Apple APIs; KeyboardShortcuts 2.4.0 pinned)
