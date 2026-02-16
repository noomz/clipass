# Phase 8: App Behavior - Research

**Researched:** 2026-02-16
**Domain:** macOS app settings — launch-at-login, configurable limits, keyboard shortcut recorder, scheduled cleanup
**Confidence:** HIGH

## Summary

Phase 8 fills in the `GeneralSettingsView` placeholder (already scaffolded in SettingsView.swift as "General" tab) with four concrete app behavior controls: Launch at Login toggle, configurable max history items, global hotkey customization, and auto-cleanup by age.

The codebase is well-prepared for this phase. The `ClipboardMonitor` already has `maxItems` and `pruneOldItems()` — they just need to be made configurable via `@AppStorage` instead of hardcoded to 100. The `KeyboardShortcuts` library (v2.4.0, already a dependency) includes a built-in `Recorder` SwiftUI view that handles shortcut recording, storage, and conflict detection. Only one new dependency is needed: `LaunchAtLogin-Modern` (v1.1.0), which is a single-file package using `SMAppService` and provides a drop-in `LaunchAtLogin.Toggle()` SwiftUI view.

**Primary recommendation:** This phase requires NO new SwiftData models — all settings use `@AppStorage` (UserDefaults). The work is: (1) add LaunchAtLogin-Modern dependency, (2) make `ClipboardMonitor.maxItems` read from `@AppStorage`, (3) add `KeyboardShortcuts.Recorder` to settings, (4) add a periodic timer for age-based cleanup, and (5) build the `GeneralSettingsView` form with all four controls.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| LaunchAtLogin-Modern | 1.1.0 | "Launch at Login" toggle using SMAppService | Only modern solution; by Sindre Sorhus (same author as KeyboardShortcuts); uses Apple's SMAppService API; single file, no bloat |
| KeyboardShortcuts | 2.4.0 (already installed) | Global hotkey recorder UI | Already a dependency; built-in `Recorder` view handles recording, UserDefaults storage, and system/menu conflict detection |
| SwiftUI @AppStorage | Built-in | Persist settings to UserDefaults | Standard pattern already used in codebase (`previewMaxLength`); no SwiftData needed for simple key-value prefs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ServiceManagement (SMAppService) | macOS 13+ system framework | Powers LaunchAtLogin-Modern under the hood | Automatically used; no direct import needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| LaunchAtLogin-Modern | Direct SMAppService calls | More boilerplate; LaunchAtLogin-Modern is literally one file that wraps SMAppService — no reason to hand-roll |
| @AppStorage | SwiftData model for settings | Over-engineering; @AppStorage is the standard for simple key-value preferences |
| Timer for auto-cleanup | Background task scheduler | Timer is simpler; app is always running (menu bar), so a periodic check is sufficient |

**Installation (Package.swift change):**
```swift
dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.0.0"),
],
targets: [
    .executableTarget(
        name: "clipass",
        dependencies: ["KeyboardShortcuts", "LaunchAtLogin"],
        path: "clipass",
        exclude: ["Info.plist", "AppIcon.icns", "AppIcon.iconset"]
    ),
],
```

Note: The product name from LaunchAtLogin-Modern is `"LaunchAtLogin"` (not `"LaunchAtLogin-Modern"`).

## Architecture Patterns

### No New Files Strategy

This phase modifies existing files rather than creating new ones. No new SwiftData models are needed.

**Files to modify:**
```
Package.swift                           — add LaunchAtLogin-Modern dependency
clipass/clipassApp.swift                — add auto-cleanup timer, wire configurable maxItems
clipass/Services/ClipboardMonitor.swift — read maxItems from @AppStorage instead of hardcoded
clipass/Views/SettingsView.swift        — build out GeneralSettingsView with all 4 controls
```

### Pattern 1: @AppStorage for All Settings

**What:** All four settings (launch-at-login state is managed by LaunchAtLogin itself, but maxItems, cleanup age, etc.) use `@AppStorage` backed by UserDefaults.
**When to use:** Simple key-value preferences that don't need relationships or queries.
**Example:**
```swift
// Source: Existing pattern in HistoryItemRow.swift, DisplaySettingsView.swift
@AppStorage("maxHistoryItems") private var maxHistoryItems = 100
@AppStorage("autoCleanupDays") private var autoCleanupDays = 0  // 0 = disabled
```

### Pattern 2: LaunchAtLogin Drop-in Toggle

**What:** `LaunchAtLogin.Toggle()` is a complete SwiftUI toggle that handles all SMAppService state management internally.
**When to use:** Settings view for BEHV-01.
**Example:**
```swift
// Source: https://github.com/sindresorhus/LaunchAtLogin-Modern/blob/main/readme.md
import LaunchAtLogin

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                LaunchAtLogin.Toggle()
            } header: {
                Text("Startup")
            }
        }
    }
}
```

**Critical:** Never set `LaunchAtLogin.isEnabled = true` programmatically on first launch. Mac App Store guidelines require it to be user-initiated only.

### Pattern 3: KeyboardShortcuts.Recorder

**What:** Built-in SwiftUI view that lets users record a new keyboard shortcut. It stores to UserDefaults, validates against system conflicts, and shows warnings.
**When to use:** Settings view for BEHV-03.
**Example:**
```swift
// Source: https://github.com/sindresorhus/KeyboardShortcuts/blob/main/Sources/KeyboardShortcuts/Recorder.swift
import KeyboardShortcuts

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle Clipboard:", name: .toggleClipboard)
            } header: {
                Text("Hotkey")
            }
        }
    }
}
```

The `Recorder` uses the `.toggleClipboard` name already defined in `clipassApp.swift`. It reads the current shortcut from UserDefaults and writes changes back. The existing `KeyboardShortcuts.onKeyUp(for: .toggleClipboard)` handler will automatically pick up user changes — no re-registration needed.

### Pattern 4: Configurable maxItems with Immediate Pruning

**What:** Make `ClipboardMonitor.maxItems` read from `@AppStorage` and trigger pruning when the value decreases.
**When to use:** BEHV-02.
**Example:**
```swift
// In ClipboardMonitor
@AppStorage("maxHistoryItems") var maxItems: Int = 100

// The existing pruneOldItems() already works with self.maxItems
// Just need to also prune when the setting changes
```

In the Settings view, use `onChange` to trigger immediate pruning:
```swift
@AppStorage("maxHistoryItems") private var maxHistoryItems = 100
@Environment(\.modelContext) private var modelContext

Stepper("Maximum items: \(maxHistoryItems)", value: $maxHistoryItems, in: 10...1000, step: 10)
    .onChange(of: maxHistoryItems) { _, newValue in
        pruneToLimit(newValue, context: modelContext)
    }
```

### Pattern 5: Periodic Auto-Cleanup Timer

**What:** A timer in AppServices that periodically deletes items older than the configured age.
**When to use:** BEHV-04.
**Example:**
```swift
// In AppServices or ClipboardMonitor
private func startAutoCleanupTimer() {
    Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
        self?.performAutoCleanup()
    }
}

private func performAutoCleanup() {
    let days = UserDefaults.standard.integer(forKey: "autoCleanupDays")
    guard days > 0 else { return }
    
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    let predicate = #Predicate<ClipboardItem> { $0.timestamp < cutoffDate }
    let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
    
    // fetch and delete items older than cutoff
}
```

### Anti-Patterns to Avoid
- **SwiftData model for simple settings:** Don't create a `Settings` @Model. @AppStorage/UserDefaults is the right tool for key-value preferences.
- **Auto-enabling launch at login:** Apple will reject apps that enable this without user action. Always let the toggle default to off.
- **Re-registering keyboard shortcuts on change:** `KeyboardShortcuts.onKeyUp(for:)` automatically tracks shortcut changes via UserDefaults KVO. No need to re-register handlers when user records a new shortcut.
- **Polling too frequently for cleanup:** Hourly (3600s) is more than sufficient for age-based cleanup. Don't poll every second.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch at Login | Custom SMAppService wrapper | `LaunchAtLogin-Modern` | Edge cases with re-registration, error handling, observable state management — all handled |
| Keyboard shortcut recorder | Custom NSEvent monitoring + UI | `KeyboardShortcuts.Recorder` | System shortcut conflict detection, localization, proper key capture, UserDefaults integration — deceptively complex |
| Keyboard shortcut storage | Custom UserDefaults serialization | Built-in KeyboardShortcuts storage | The library manages its own UserDefaults keys; don't interfere |

**Key insight:** Both LaunchAtLogin-Modern and KeyboardShortcuts.Recorder are drop-in SwiftUI views with zero configuration. The entire settings UI for BEHV-01 and BEHV-03 is literally two lines of SwiftUI code each.

## Common Pitfalls

### Pitfall 1: @AppStorage Not Reactive Across Instances
**What goes wrong:** `@AppStorage` in the settings view updates UserDefaults, but `ClipboardMonitor` reading the same key via a property doesn't update.
**Why it happens:** `@AppStorage` only triggers view updates in SwiftUI views. Non-view classes need to read from `UserDefaults.standard` directly at use-time.
**How to avoid:** In `ClipboardMonitor`, read `UserDefaults.standard.integer(forKey: "maxHistoryItems")` inside `pruneOldItems()` each time it runs, rather than caching the value in a property. Alternatively, use `@AppStorage` directly in ClipboardMonitor since it's `@Observable`.
**Warning signs:** Settings changes don't take effect until app restart.

### Pitfall 2: Not Pruning on Setting Decrease
**What goes wrong:** User sets max items from 100 to 20, but 80 old items persist until new clips push them out.
**Why it happens:** Pruning only runs during `poll()` after a new clipboard event.
**How to avoid:** Trigger immediate pruning in the `onChange` handler when `maxHistoryItems` decreases.
**Warning signs:** Item count exceeds the configured maximum after changing settings.

### Pitfall 3: Auto-Cleanup Timer Not on Main Actor
**What goes wrong:** SwiftData `ModelContext` access from a non-main thread causes crashes or data corruption.
**Why it happens:** `Timer.scheduledTimer` fires on the run loop it was created on, but SwiftData contexts are main-actor-bound.
**How to avoid:** Either create the timer on the main run loop, or dispatch cleanup work to `DispatchQueue.main.async`. The existing `ClipboardMonitor` pattern of `DispatchQueue.main.async` for model context access is the right pattern to follow.
**Warning signs:** Crashes with "ModelContext must be accessed on the main actor".

### Pitfall 4: LaunchAtLogin Auto-Enable on First Launch
**What goes wrong:** App gets rejected from Mac App Store.
**Why it happens:** Developer sets `LaunchAtLogin.isEnabled = true` in app init or first-run logic.
**How to avoid:** Never programmatically enable. Only use `LaunchAtLogin.Toggle()` which requires user interaction.
**Warning signs:** App Store review rejection citing guideline violation.

### Pitfall 5: Cleanup Deleting Items User Expects to Keep
**What goes wrong:** User sets auto-cleanup to 7 days, loses important clipboard items.
**Why it happens:** No warning or confirmation before deletion.
**How to avoid:** Show the current item count that would be affected when user changes the setting. Consider running cleanup only on items that weren't recently accessed/pasted.
**Warning signs:** User complaints about missing items.

### Pitfall 6: KeyboardShortcuts.Recorder Requires Name-Based Init
**What goes wrong:** Developer tries to create a Recorder with a binding instead of a Name, then wonders why the global hotkey doesn't update.
**Why it happens:** Binding-based Recorder doesn't auto-register as a global hotkey. Only Name-based Recorder does.
**How to avoid:** Always use `KeyboardShortcuts.Recorder("Label:", name: .toggleClipboard)` — the name-based initializer that stores to UserDefaults and auto-updates the global hotkey registration.
**Warning signs:** User records a new shortcut but the old one still activates.

## Code Examples

Verified patterns from official sources:

### Complete GeneralSettingsView
```swift
// Source: Synthesis of verified API patterns from LaunchAtLogin-Modern and KeyboardShortcuts
import SwiftUI
import SwiftData
import LaunchAtLogin
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 100
    @AppStorage("autoCleanupDays") private var autoCleanupDays = 0
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section {
                LaunchAtLogin.Toggle()
            } header: {
                Text("Startup")
            }

            Section {
                Stepper("Maximum items: \(maxHistoryItems)",
                        value: $maxHistoryItems,
                        in: 10...1000,
                        step: 10)
                    .onChange(of: maxHistoryItems) { _, newValue in
                        pruneToLimit(newValue)
                    }
            } header: {
                Text("History")
            }

            Section {
                KeyboardShortcuts.Recorder("Toggle Clipboard:", name: .toggleClipboard)
            } header: {
                Text("Hotkey")
            }

            Section {
                Picker("Auto-delete items older than:", selection: $autoCleanupDays) {
                    Text("Never").tag(0)
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
            } header: {
                Text("Cleanup")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func pruneToLimit(_ limit: Int) {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let allItems = try? modelContext.fetch(descriptor) else { return }
        if allItems.count > limit {
            for item in allItems.suffix(from: limit) {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }
}
```

### Making ClipboardMonitor Read Dynamic maxItems
```swift
// Source: Existing pattern in ClipboardMonitor.swift, modified for @AppStorage
// In ClipboardMonitor, change:
//   let maxItems: Int = 100
// To:
//   var maxItems: Int { UserDefaults.standard.integer(forKey: "maxHistoryItems").nonZero ?? 100 }
//
// Or since ClipboardMonitor is @Observable, use @AppStorage directly:
@AppStorage("maxHistoryItems") var maxItems: Int = 100
```

### Auto-Cleanup in AppServices
```swift
// Source: Standard Timer + SwiftData pattern, following existing ClipboardMonitor conventions
func startAutoCleanupTimer() {
    // Run cleanup once on startup, then every hour
    performAutoCleanup()
    Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
        DispatchQueue.main.async {
            self?.performAutoCleanup()
        }
    }
}

@MainActor
func performAutoCleanup() {
    let days = UserDefaults.standard.integer(forKey: "autoCleanupDays")
    guard days > 0 else { return }
    
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    let context = modelContainer.mainContext
    let predicate = #Predicate<ClipboardItem> { $0.timestamp < cutoffDate }
    var descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
    
    guard let oldItems = try? context.fetch(descriptor) else { return }
    for item in oldItems {
        context.delete(item)
    }
    if !oldItems.isEmpty {
        try? context.save()
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Login Items (LSSharedFileListInsertItemURL) | SMAppService (macOS 13+) | macOS 13, 2022 | Old API removed; LaunchAtLogin-Modern wraps SMAppService |
| MASShortcut / custom Carbon event tap | KeyboardShortcuts library | 2020+ | SwiftUI native, sandboxed, conflict detection built-in |
| NSUserDefaults direct | @AppStorage property wrapper | SwiftUI 2.0, 2020 | Reactive, automatic view updates |

**Deprecated/outdated:**
- `LSSharedFileListInsertItemURL` for login items: Removed in macOS 13. Use `SMAppService` (via LaunchAtLogin-Modern).
- The older `LaunchAtLogin` package (non-Modern): Used helper apps. LaunchAtLogin-Modern is simpler and the recommended replacement.

## Open Questions

1. **Should the Stepper for maxItems allow free-text entry?**
   - What we know: Stepper gives clean increments (10-step); TextField allows arbitrary values
   - What's unclear: Whether users want fine-grained control (e.g., exactly 42 items)
   - Recommendation: Start with Stepper (simpler UX); can add TextField later if needed

2. **Should auto-cleanup show a count of affected items before applying?**
   - What we know: Immediate deletion with no undo could surprise users
   - What's unclear: Whether this is a real concern or over-engineering
   - Recommendation: Show a small info text like "X items currently older than Y days" but don't require confirmation — the Picker is clear enough

3. **Timer lifecycle for auto-cleanup**
   - What we know: The timer should live in AppServices (always alive for menu bar app)
   - What's unclear: Whether to use `Timer.scheduledTimer` or `DispatchSourceTimer` (like ClipboardMonitor uses)
   - Recommendation: Use `Timer.scheduledTimer` since hourly granularity doesn't need the precision of `DispatchSourceTimer`. Run on main run loop since SwiftData requires main actor access.

## Sources

### Primary (HIGH confidence)
- LaunchAtLogin-Modern GitHub repo (https://github.com/sindresorhus/LaunchAtLogin-Modern) — full README, source code read
- LaunchAtLogin-Modern source code (https://raw.githubusercontent.com/sindresorhus/LaunchAtLogin-Modern/main/Sources/LaunchAtLogin/LaunchAtLogin.swift) — complete implementation verified
- LaunchAtLogin-Modern Package.swift — verified product name is `"LaunchAtLogin"`, swift-tools-version: 5.9, platforms macOS 13+
- KeyboardShortcuts GitHub repo (https://github.com/sindresorhus/KeyboardShortcuts) — full README, API docs link
- KeyboardShortcuts Recorder source (https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/main/Sources/KeyboardShortcuts/Recorder.swift) — verified initializer signatures and behavior
- Package.resolved — confirmed KeyboardShortcuts v2.4.0 currently installed
- Existing codebase — ClipboardMonitor.swift, SettingsView.swift, clipassApp.swift all read and analyzed

### Secondary (MEDIUM confidence)
- @AppStorage behavior across view/non-view classes — based on SwiftUI framework knowledge; well-documented pattern

### Tertiary (LOW confidence)
- None — all findings verified from primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified from source, one already in use
- Architecture: HIGH — patterns follow existing codebase conventions exactly
- Pitfalls: HIGH — based on verified API behavior and existing code analysis

**Research date:** 2026-02-16
**Valid until:** 2026-03-16 (stable libraries, no breaking changes expected)
