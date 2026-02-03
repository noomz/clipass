# Phase 1: Foundation - Research

**Researched:** 2026-02-03
**Domain:** macOS menu bar app with clipboard monitoring (Swift/SwiftUI)
**Confidence:** HIGH

<research_summary>
## Summary

Researched the macOS ecosystem for building a menu bar clipboard manager with SwiftUI. The standard approach uses SwiftUI's `MenuBarExtra` (macOS 13+) for the menu bar UI, polling-based clipboard monitoring via `NSPasteboard.changeCount`, and the `KeyboardShortcuts` library for global hotkeys.

Key finding: macOS does NOT provide clipboard change notifications like iOS does. All clipboard managers must poll `NSPasteboard.changeCount` — this is lightweight because it only checks a counter, not content. The standard polling interval is 100-500ms.

**Primary recommendation:** Use MenuBarExtra with `.window` style for custom UI, poll NSPasteboard.changeCount at 100-500ms intervals, use KeyboardShortcuts for global hotkey registration.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI MenuBarExtra | macOS 13+ | Menu bar scene | Native SwiftUI, no AppKit delegation needed |
| NSPasteboard | AppKit | Clipboard access | Only API for clipboard on macOS |
| KeyboardShortcuts | 2.x | Global hotkey registration | SwiftUI-native, sandboxed, App Store safe |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| OnPasteboardChange | 1.x | SwiftUI modifier for clipboard changes | If you want a declarative SwiftUI approach |
| HotKey | 0.2.1 | Simple hardcoded hotkeys | For fixed shortcuts (simpler than KeyboardShortcuts) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MenuBarExtra | NSStatusItem (AppKit) | AppKit gives more control, MenuBarExtra is simpler |
| KeyboardShortcuts | HotKey | HotKey is simpler but no user customization UI |
| KeyboardShortcuts | CGEventTap | Lower-level, requires Input Monitoring permission |
| KeyboardShortcuts | MASShortcut | Objective-C based, more features but older |

**Installation:**
```swift
// Package.swift dependencies
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
// or
.package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
clipass/
├── clipassApp.swift           # @main, MenuBarExtra scene
├── Views/
│   ├── ClipboardPopup.swift   # Main popup window content
│   ├── ClipboardRow.swift     # Single history item view
│   └── SearchBar.swift        # Search/filter UI
├── Services/
│   ├── ClipboardMonitor.swift # Polling-based clipboard watcher
│   └── HotkeyManager.swift    # Global shortcut registration
├── Models/
│   ├── ClipboardItem.swift    # Single clipboard entry
│   └── ClipboardHistory.swift # History storage
└── Info.plist                 # LSUIElement = YES
```

### Pattern 1: MenuBarExtra with Window Style
**What:** Use `.menuBarExtraStyle(.window)` for custom SwiftUI content
**When to use:** When you need more than a simple menu (search, previews, etc.)
**Example:**
```swift
// Source: Apple developer documentation
@main
struct clipassApp: App {
    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "clipboard") {
            ClipboardPopup()
        }
        .menuBarExtraStyle(.window)
    }
}
```

### Pattern 2: Polling-Based Clipboard Monitor
**What:** Timer-based polling of NSPasteboard.changeCount
**When to use:** Always — macOS has no clipboard notification API
**Example:**
```swift
// Source: Maccy, PlainPasta implementations
@Observable
class ClipboardMonitor {
    private var pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: DispatchSourceTimer?

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start(interval: TimeInterval = 0.5) {
        let queue = DispatchQueue(label: "clipboard.monitor")
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval)
        timer?.setEventHandler { [weak self] in
            self?.checkClipboard()
        }
        timer?.resume()
    }

    private func checkClipboard() {
        guard lastChangeCount != pasteboard.changeCount else { return }
        lastChangeCount = pasteboard.changeCount
        // Clipboard changed - capture content
        if let string = pasteboard.string(forType: .string) {
            // Store in history
        }
    }
}
```

### Pattern 3: Source App Detection
**What:** Track which app the clipboard content came from
**When to use:** For app-specific transform rules
**Example:**
```swift
// Source: NSWorkspace documentation
func captureSourceApp() -> String? {
    return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
}

// Listen for app changes
NotificationCenter.default.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    object: nil,
    queue: .main
) { notification in
    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
        print("Active app: \(app.bundleIdentifier ?? "unknown")")
    }
}
```

### Anti-Patterns to Avoid
- **Polling clipboard content directly:** Poll changeCount only, read content when changed
- **Using KVO on NSPasteboard:** There's no KVO support for clipboard changes
- **Expecting clipboard notifications:** macOS doesn't have them (iOS does)
- **Short polling without throttling:** 100ms is fine, but batch UI updates
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Global hotkey registration | Carbon API wrappers | KeyboardShortcuts | Sandboxing, permissions, UI recorder included |
| Menu bar app scaffold | NSStatusItem + delegate | MenuBarExtra | SwiftUI native, less boilerplate |
| Hotkey customization UI | Custom key recorder | KeyboardShortcuts.Recorder | Handles conflicts, UserDefaults storage |
| Cross-platform pasteboard | Abstraction layer | OnPasteboardChange (if needed) | Tested iOS/macOS abstraction |

**Key insight:** The clipboard monitoring itself is simple (just poll changeCount), but global hotkey registration involves Carbon APIs, accessibility permissions, and conflict detection. Use KeyboardShortcuts to avoid these headaches.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Missing Quit Button
**What goes wrong:** Users can't quit the app
**Why it happens:** LSUIElement hides from Dock, no Cmd+Q without menu
**How to avoid:** Always include a Quit button in menu bar UI
**Warning signs:** App runs forever, users force-quit
```swift
Button("Quit clipass") {
    NSApplication.shared.terminate(nil)
}
.keyboardShortcut("q", modifiers: .command)
```

### Pitfall 2: Polling Too Fast Without Throttling
**What goes wrong:** High CPU usage, battery drain
**Why it happens:** 100ms polling with heavy content processing
**How to avoid:** Poll fast (100ms), but batch/throttle UI updates
**Warning signs:** Activity Monitor shows high CPU when idle

### Pitfall 3: Not Handling Transient/Concealed Types
**What goes wrong:** Password manager contents appear in history
**Why it happens:** Not filtering secure pasteboard types
**How to avoid:** Skip items with these UTIs:
- `org.nspasteboard.TransientType`
- `org.nspasteboard.ConcealedType`
- `org.nspasteboard.AutoGeneratedType`
**Warning signs:** 1Password/Bitwarden entries in history

### Pitfall 4: Accessibility Permission Issues
**What goes wrong:** Global hotkeys don't work
**Why it happens:** Missing Input Monitoring or Accessibility permissions
**How to avoid:** Use KeyboardShortcuts (handles permissions properly)
**Warning signs:** Hotkeys work in dev, fail in release

### Pitfall 5: macOS 15.4+ Clipboard Privacy
**What goes wrong:** System prompts user for clipboard access
**Why it happens:** New "Paste from Other Apps" privacy controls
**How to avoid:** Be aware of new `accessBehavior` property, design for permission prompts
**Warning signs:** Clipboard access fails silently or prompts repeatedly
</common_pitfalls>

<code_examples>
## Code Examples

### Complete MenuBarExtra App Shell
```swift
// Source: Combined from Apple docs + community patterns
import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard")
}

@main
struct clipassApp: App {
    @StateObject private var clipboardMonitor = ClipboardMonitor()

    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
            ClipboardPopup(monitor: clipboardMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}
```

### Clipboard Monitor with Source App
```swift
// Source: Community pattern from Maccy, PlainPasta
import AppKit
import Observation

@Observable
class ClipboardMonitor {
    private(set) var history: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: DispatchSourceTimer?

    private let ignoredTypes = [
        "org.nspasteboard.TransientType",
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.AutoGeneratedType"
    ]

    func start() {
        lastChangeCount = pasteboard.changeCount

        let queue = DispatchQueue(label: "com.clipass.monitor", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(500))
        timer?.setEventHandler { [weak self] in
            self?.poll()
        }
        timer?.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Check for ignored types
        if let types = pasteboard.types {
            for type in types {
                if ignoredTypes.contains(type.rawValue) {
                    return // Skip secure content
                }
            }
        }

        guard let content = pasteboard.string(forType: .string) else { return }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let item = ClipboardItem(
            content: content,
            sourceApp: sourceApp,
            timestamp: Date()
        )

        DispatchQueue.main.async {
            self.history.insert(item, at: 0)
        }
    }
}
```

### Global Hotkey Setup
```swift
// Source: KeyboardShortcuts library docs
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Show clipboard:", name: .toggleClipboard)
        }
    }
}

// In App init or onAppear
func setupHotkey() {
    KeyboardShortcuts.onKeyUp(for: .toggleClipboard) {
        // Toggle popup visibility
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

### Info.plist for Menu Bar App
```xml
<!-- Add to Info.plist -->
<key>LSUIElement</key>
<true/>
```
Or in Xcode: Target → Info → "Application is agent (UIElement)" = YES
</code_examples>

<sota_updates>
## State of the Art (2025-2026)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSStatusItem + AppDelegate | MenuBarExtra scene | macOS 13 (2022) | Pure SwiftUI menu bar apps |
| Carbon RegisterEventHotKey | KeyboardShortcuts / CGEventTap | 2020+ | Sandboxed, modern API |
| declareTypes(_:owner:) | clearContents() + setString | macOS 10.6+ | Modern clipboard writing |

**New tools/patterns to consider:**
- **macOS 15.4+ Clipboard Privacy:** New `accessBehavior` property on NSPasteboard, "Paste from Other Apps" system setting
- **@Observable macro:** Swift 5.9+ — cleaner than ObservableObject for monitors
- **MenuBarExtra .window style:** Allows full SwiftUI views in popup, not just menus

**Deprecated/outdated:**
- **Carbon APIs for hotkeys:** Use KeyboardShortcuts instead
- **NSStatusItem for pure SwiftUI apps:** MenuBarExtra is preferred
- **declareTypes(_:owner:):** Use clearContents() + setString pattern
</sota_updates>

<open_questions>
## Open Questions

1. **Window positioning for popup**
   - What we know: MenuBarExtra with .window style creates a popover-like window
   - What's unclear: How much control over exact positioning and sizing
   - Recommendation: Test with .window style first, fallback to NSPanel if needed

2. **Performance with large history**
   - What we know: Polling is lightweight, but displaying thousands of items may lag
   - What's unclear: Optimal history size limit
   - Recommendation: Start with 1000 items, implement virtual scrolling if needed
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- [Apple NSPasteboard Documentation](https://developer.apple.com/documentation/appkit/nspasteboard) - Core API reference
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkey library
- [Apple MenuBarExtra Documentation](https://developer.apple.com/news/?id=2293tuu9) - Native SwiftUI menu bar

### Secondary (MEDIUM confidence)
- [Maccy GitHub](https://github.com/p0deje/Maccy) - Open source clipboard manager, verified patterns
- [PlainPasta PasteboardMonitor](https://github.com/hisaac/PlainPasta/blob/main/PlainPasta/PasteboardMonitor.swift) - Polling implementation
- [OnPasteboardChange](https://github.com/kyle-n/OnPasteboardChange) - SwiftUI pasteboard modifier
- [Build a macOS menu bar utility](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) - Tutorial with patterns
- [SwiftUI MenuBarExtra Tutorial](https://sarunw.com/posts/swiftui-menu-bar-app/) - MenuBarExtra setup guide

### Tertiary (LOW confidence - needs validation)
- macOS 15.4 clipboard privacy changes - Verified via [Michael Tsai's blog](https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4/)
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: SwiftUI MenuBarExtra, NSPasteboard
- Ecosystem: KeyboardShortcuts, polling patterns
- Patterns: Menu bar architecture, clipboard monitoring
- Pitfalls: Permissions, transient types, privacy

**Confidence breakdown:**
- Standard stack: HIGH - verified with official docs and production apps
- Architecture: HIGH - patterns from Maccy, PlainPasta, tutorials
- Pitfalls: HIGH - documented across multiple sources
- Code examples: HIGH - from library docs and open source apps

**Research date:** 2026-02-03
**Valid until:** 2026-03-03 (30 days - SwiftUI/AppKit ecosystem stable)
</metadata>

---

*Phase: 01-foundation*
*Research completed: 2026-02-03*
*Ready for planning: yes*
