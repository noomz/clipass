# Pitfalls Research: v1.1 More Control

**Domain:** Adding settings/configuration to an existing macOS menu bar app
**Researched:** 2026-02-06
**Confidence:** HIGH (verified with official packages, real-world issues)

## LaunchAtLogin Pitfalls

### Pitfall 1: Auto-enabling on First Launch (App Store Rejection)

**What goes wrong:** Setting `LaunchAtLogin.isEnabled = true` by default or on first launch causes App Store rejection.

**Why it happens:** Apple's Mac App Store guidelines require "launch at login" functionality to be enabled only in response to explicit user action.

**Consequences:** App Store rejection, wasted review cycles.

**Warning signs:**
- Any code path that sets `isEnabled = true` without direct user interaction
- Setting default value in UserDefaults/AppStorage

**Prevention:**
```swift
// WRONG - Auto-enable is forbidden
@AppStorage("launchAtLogin") var launchAtLogin = true

// WRONG - Setting on first launch
if isFirstLaunch {
    LaunchAtLogin.isEnabled = true
}

// CORRECT - User must toggle explicitly
LaunchAtLogin.Toggle() // Built-in toggle handles this correctly
```

**Source:** [LaunchAtLogin-Modern README](https://github.com/sindresorhus/LaunchAtLogin-Modern) - explicit warning about App Store guidelines.

**Phase impact:** Settings UI phase — ensure toggle is disabled by default.

---

### Pitfall 2: Using Legacy Package Instead of Modern API

**What goes wrong:** Using `LaunchAtLogin` (legacy) instead of `LaunchAtLogin-Modern` for macOS 13+ targets requires complex helper app setup that's easy to misconfigure.

**Why it happens:** Search results often show the legacy package first; developers don't realize a simpler modern API exists.

**Consequences:**
- Build errors: "No such file or directory" when archiving
- Code signing issues with helper app
- Complex "Run Script Phase" setup required
- Build fails if script phase order is wrong

**Warning signs:**
- Build phase scripts copying helper apps
- References to `LaunchAtLoginHelper.app`
- Using `SMLoginItemSetEnabled` directly

**Prevention:**
```swift
// For macOS 13+, use the modern package:
// Package: https://github.com/sindresorhus/LaunchAtLogin-Modern

import LaunchAtLogin

// That's it - no build scripts, no helper apps
LaunchAtLogin.Toggle() // SwiftUI toggle
LaunchAtLogin.isEnabled = true // Programmatic access
```

**Source:** LaunchAtLogin-Modern vs LaunchAtLogin-Legacy comparison. clipass targets macOS 14+, so only needs modern package.

**Phase impact:** Stack selection — use `LaunchAtLogin-Modern` package, not legacy.

---

### Pitfall 3: Testing LaunchAtLogin with Multiple App Builds

**What goes wrong:** Launch at login doesn't work during development/testing, even after enabling it.

**Why it happens:** macOS caches the login item and may pick an older build of the app that doesn't have the feature enabled.

**Consequences:** Developers think the feature is broken, waste time debugging.

**Warning signs:**
- Feature works in production but not during testing
- Multiple app copies in Applications, Downloads, etc.
- Inconsistent behavior between clean and dirty builds

**Prevention:**
1. Bump version & build number before testing
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. Search for and remove all other builds of the app
4. Clear login items: System Preferences → Users & Groups → Login Items

**Source:** [LaunchAtLogin FAQ](https://github.com/sindresorhus/LaunchAtLogin-Legacy#my-app-doesnt-launch-at-login-when-testing)

**Phase impact:** QA/Testing phase — document this for testers.

---

## Pattern Matching Pitfalls

### Pitfall 4: Regex Compilation on Every Clipboard Change

**What goes wrong:** Compiling regex patterns on every clipboard poll (500ms) wastes CPU and delays clipboard processing.

**Why it happens:** Current `TransformEngine.transform()` creates new `Regex` objects on every call:
```swift
// Current implementation (lines 92-94):
let regex = try Regex(rule.pattern)
result = result.replacing(regex, with: rule.replacement)
```

**Consequences:**
- Increased CPU usage (regex compilation is expensive)
- Battery drain on laptops
- Delays in clipboard processing with many rules

**Warning signs:**
- CPU spikes correlating with clipboard activity
- Noticeable lag when pasting after many rules added
- Energy impact in Activity Monitor

**Prevention:**
```swift
// Cache compiled regex patterns
class PatternMatcher {
    private var compiledPatterns: [UUID: Regex<AnyRegexOutput>] = [:]
    
    func getPattern(for rule: TransformRule) -> Regex<AnyRegexOutput>? {
        if let cached = compiledPatterns[rule.id] {
            return cached
        }
        guard let regex = try? Regex(rule.pattern) else { return nil }
        compiledPatterns[rule.id] = regex
        return regex
    }
    
    func invalidate(ruleId: UUID) {
        compiledPatterns.removeValue(forKey: ruleId)
    }
}
```

**Phase impact:** Pattern matching implementation — cache compiled patterns, invalidate on rule edit.

---

### Pitfall 5: User-Supplied Regex Without Validation

**What goes wrong:** Invalid regex patterns cause silent failures or confusing error states in the UI.

**Why it happens:** Users can type any text as a "pattern" — not all strings are valid regex.

**Consequences:**
- Rules that never match (user thinks feature is broken)
- Confusing error messages
- Rules saved but non-functional

**Warning signs:**
- Rule appears enabled but never applies
- Console errors about invalid patterns
- User reports "rules don't work"

**Prevention:**
```swift
// Validate regex before saving
struct RuleEditorView: View {
    @State private var patternError: String?
    
    func validatePattern(_ pattern: String) -> Bool {
        do {
            _ = try Regex(pattern)
            patternError = nil
            return true
        } catch {
            patternError = "Invalid pattern: \(error.localizedDescription)"
            return false
        }
    }
    
    // Show real-time validation in UI
    TextField("Pattern", text: $pattern)
        .onChange(of: pattern) { validatePattern($0) }
    if let error = patternError {
        Text(error).foregroundColor(.red).font(.caption)
    }
}
```

**Phase impact:** Rule editor UI — add real-time validation with clear error messages.

---

### Pitfall 6: Catastrophic Backtracking (ReDoS)

**What goes wrong:** Certain regex patterns can take exponential time to match, freezing the app when matching specific clipboard content.

**Why it happens:** Patterns with nested quantifiers like `(a+)+`, `(a*)*`, or `(a|a)+` exhibit catastrophic backtracking on crafted input.

**Consequences:**
- App freeze/hang on certain clipboard content
- Watchdog timeout kills app
- Appears random to user (depends on clipboard content)

**Warning signs:**
- Patterns with nested quantifiers: `(.+)+`, `(.*)*`, `(\s*)*`
- App hangs "randomly" (actually when specific content is copied)
- High CPU with certain clipboard content

**Prevention:**
```swift
// Add timeout to regex matching
func safeMatch(pattern: Regex<AnyRegexOutput>, in text: String, timeout: TimeInterval = 0.1) -> Bool {
    var result = false
    let semaphore = DispatchSemaphore(value: 0)
    
    DispatchQueue.global(qos: .userInitiated).async {
        result = text.contains(pattern)
        semaphore.signal()
    }
    
    let timeoutResult = semaphore.wait(timeout: .now() + timeout)
    return timeoutResult == .success && result
}

// Or use possessive quantifiers (Swift Regex supports these):
// Instead of (.+)+  use (.++)+ or atomic groups
```

**Phase impact:** Pattern matching — implement timeout or use async matching for user-defined patterns.

---

### Pitfall 7: Ignore Patterns Blocking Legitimate Content

**What goes wrong:** Overly broad ignore patterns skip content users wanted to keep.

**Why it happens:** Users create patterns like `.*password.*` that match unintended content like "password reset complete" or documentation about passwords.

**Consequences:**
- User confusion about "missing" clipboard entries
- Difficult to diagnose (content silently dropped)
- Users don't realize their ignore pattern is too broad

**Warning signs:**
- User reports "clipboard history is missing items"
- Patterns with `.*` on both sides
- No feedback when content is ignored

**Prevention:**
```swift
// Show ignored items in a separate section (collapsed by default)
// with reason for ignoring
struct ClipboardPopup: View {
    @State private var showIgnored = false
    
    // In history list:
    if showIgnored {
        Section("Ignored") {
            ForEach(ignoredItems) { item in
                HStack {
                    Text(item.preview)
                    Text("Matched: \(item.matchedPattern)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

**Phase impact:** Ignore patterns — provide visibility into what's being ignored.

---

## Settings Migration Pitfalls

### Pitfall 8: SwiftData Schema Changes Causing App Crashes

**What goes wrong:** App crashes on launch after update when SwiftData model schema changes.

**Why it happens:** SwiftData can't automatically migrate when model properties are added/removed/changed without explicit migration plan.

**Consequences:**
- App refuses to open after update
- Complete data loss if user deletes/reinstalls
- 1-star reviews, support tickets

**Warning signs:**
- Adding new properties to `@Model` classes
- Changing property types
- Making required properties optional (or vice versa)

**Prevention:**
```swift
// For v1.1, implement graceful recovery:
func makeModelContainer() -> ModelContainer {
    let schema = Schema([ClipboardItem.self, TransformRule.self, Hook.self])
    let configuration = ModelConfiguration(schema: schema)
    
    do {
        return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
        // Log the error
        print("Migration failed: \(error). Resetting database.")
        
        // Delete corrupted database
        let dbURL = configuration.url
        if let url = dbURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Create fresh container
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Last resort: in-memory container
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memoryConfig])
        }
    }
}
```

**For future versions with valuable data:**
```swift
// Implement proper VersionedSchema
enum ClipboardSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [ClipboardItemV1.self] }
}

enum ClipboardSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] { [ClipboardItem.self] }
}

struct ClipboardMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ClipboardSchemaV1.self, ClipboardSchemaV2.self]
    }
    static var stages: [MigrationStage] { /* define migrations */ }
}
```

**Source:** [GitHub PR analysis](https://github.com/Geoffe-Ga/wrist-arcana/pull/47) — real-world SwiftData migration crash fix.

**Phase impact:** All phases adding new model properties — implement migration strategy first.

---

### Pitfall 9: Hardcoded Values Becoming Configurable

**What goes wrong:** Making previously hardcoded values (like `maxItems = 100`) configurable requires careful migration to avoid unexpected behavior changes.

**Current hardcoded values in clipass:**
```swift
// ClipboardMonitor.swift line 14
let maxItems: Int = 100

// ClipboardMonitor.swift line 41
timer?.schedule(deadline: .now(), repeating: .milliseconds(500))

// ClipboardMonitor.swift lines 16-20
private let ignoredTypes = [
    "org.nspasteboard.TransientType",
    "org.nspasteboard.ConcealedType",
    "org.nspasteboard.AutoGeneratedType"
]
```

**Consequences:**
- Existing users suddenly see different behavior after update
- If user sets maxItems lower than current count, pruning happens immediately
- If user sets different polling interval, performance changes

**Warning signs:**
- Converting `let` constants to UserDefaults/AppStorage backed properties
- No migration path for existing default behavior

**Prevention:**
```swift
// Use sentinel values to detect "never set by user"
@AppStorage("maxItems") private var maxItemsSetting: Int = -1

var effectiveMaxItems: Int {
    maxItemsSetting == -1 ? 100 : maxItemsSetting  // Preserve original default
}

// Or use explicit "useDefaultMaxItems" flag
@AppStorage("useDefaultMaxItems") private var useDefault = true
@AppStorage("maxItems") private var customMaxItems: Int = 100

var maxItems: Int {
    useDefault ? 100 : customMaxItems
}
```

**Phase impact:** Settings UI — preserve existing behavior for users who don't touch settings.

---

### Pitfall 10: AppStorage Type Mismatches

**What goes wrong:** Changing the type of an `@AppStorage` property between versions causes crashes or data loss.

**Why it happens:** UserDefaults stores typed data. Reading an Int as a String (or vice versa) fails.

**Consequences:**
- Crash on app launch
- Setting reverts to default unexpectedly
- Difficult to debug (happens only for users with existing preferences)

**Warning signs:**
- Changing `@AppStorage("key") var foo: Int` to `String`
- Renaming an AppStorage key without migration
- Changing optional to non-optional

**Prevention:**
```swift
// WRONG - Type change breaks existing users
// v1.0: @AppStorage("truncationLength") var length: Int = 100
// v1.1: @AppStorage("truncationLength") var length: String = "100"

// CORRECT - New key for new type, migrate old value
@AppStorage("truncationLength") private var legacyLength: Int?
@AppStorage("truncationLengthV2") private var length: String = "100"

init() {
    if let legacy = legacyLength {
        length = String(legacy)
        UserDefaults.standard.removeObject(forKey: "truncationLength")
    }
}
```

**Phase impact:** All AppStorage additions — document key names, never change types.

---

## Integration Pitfalls

### Pitfall 11: KeyboardShortcuts Conflicts with Existing Hotkey

**What goes wrong:** clipass already has a fixed hotkey (Cmd+Shift+V). Adding customizable hotkeys without migration path confuses users or creates conflicts.

**Current implementation:**
```swift
// clipassApp.swift lines 5-7
extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
}
```

**Consequences:**
- User customizes hotkey, forgets what it was, can't access app
- Hotkey conflicts with other apps not detected
- Default hotkey might already be in use by user's system

**Warning signs:**
- No "reset to default" option
- No conflict detection with system shortcuts
- No indication of current hotkey in menu bar

**Prevention:**
```swift
// Show current hotkey in menu bar tooltip or menu
MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
    // Show current hotkey prominently
    if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleClipboard) {
        Text("Press \(shortcut.description) to show")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    // Easy access to settings to change hotkey
    Button("Change Hotkey...") {
        openSettings()
    }
}

// Add reset to default button in settings
Button("Reset to Default (⌘⇧V)") {
    KeyboardShortcuts.reset(.toggleClipboard)
}
```

**Source:** [KeyboardShortcuts issues](https://github.com/sindresorhus/KeyboardShortcuts/issues/219) — conflicts not always detected.

**Phase impact:** Hotkey customization — add reset option, show current hotkey in UI.

---

### Pitfall 12: Settings Window Stealing Focus from Menu Bar Popup

**What goes wrong:** Opening Settings window from menu bar popup causes focus issues; popup might close, window might not appear, or focus is confused.

**Current implementation:**
```swift
// Uses Window scene (correct for Settings)
Window("Settings", id: "settings") {
    SettingsView()
}
```

**Consequences:**
- Settings window opens behind other windows
- Menu bar popup closes but Settings doesn't appear (focus race)
- User confusion about where Settings went

**Warning signs:**
- Settings button in popup
- No explicit window activation
- Window opens but isn't key/main

**Prevention:**
```swift
// Explicitly activate and bring to front
Button("Settings...") {
    // Close popup first to avoid race
    dismissPopup()
    
    // Small delay for UI to settle
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // Or use environment openWindow
    }
}

// Or use openWindow environment action (SwiftUI 4+)
@Environment(\.openWindow) private var openWindow

Button("Settings...") {
    openWindow(id: "settings")
}
```

**Phase impact:** Settings UI integration — test focus behavior carefully.

---

### Pitfall 13: Mutating Shared State from Settings

**What goes wrong:** Settings changes (like maxItems) don't take effect immediately because ClipboardMonitor has cached values.

**Current architecture:**
```swift
// AppServices is singleton, values read at init
@MainActor
final class AppServices {
    static let shared = AppServices()
    let clipboardMonitor = ClipboardMonitor()  // maxItems = 100 hardcoded
}
```

**Consequences:**
- User changes setting, sees no effect until restart
- Confusion about whether change was saved
- Inconsistent behavior

**Warning signs:**
- Constants in services read at init
- No observation of UserDefaults/AppStorage changes
- Settings require restart

**Prevention:**
```swift
// Option 1: Read settings on each use (simple, slight performance cost)
class ClipboardMonitor {
    @AppStorage("maxItems") private var maxItems = 100
    
    private func pruneOldItems(context: ModelContext) {
        // maxItems is read fresh from AppStorage each time
        let maxItems = self.maxItems  // Current value
        // ... pruning logic
    }
}

// Option 2: Observe changes (more complex, better for frequent reads)
class ClipboardMonitor {
    private var maxItems: Int = 100
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.maxItems = UserDefaults.standard.integer(forKey: "maxItems")
            }
            .store(in: &cancellables)
    }
}
```

**Phase impact:** All settings — ensure changes take effect immediately.

---

### Pitfall 14: Breaking Existing TransformRule/Hook Data

**What goes wrong:** Adding new properties to TransformRule or Hook models breaks existing stored rules.

**Current models:**
```swift
// TransformRule.swift
@Model class TransformRule {
    var id: UUID
    var name: String
    var pattern: String
    var replacement: String
    var sourceAppFilter: String?
    var isEnabled: Bool
    var order: Int
    var createdAt: Date
}
```

**Consequences:**
- If adding non-optional property: crash on fetch
- If changing property type: crash or data corruption
- Users lose their carefully configured rules

**Warning signs:**
- Adding required (non-optional) properties without defaults
- Changing property types
- Removing properties

**Prevention:**
```swift
// Always add new properties as optional with defaults
@Model class TransformRule {
    // Existing properties...
    
    // NEW for v1.1 - optional with sensible default
    var caseSensitive: Bool? // nil = false (backward compatible)
    var targetAppFilter: String?  // nil = all apps
    
    var isCaseSensitive: Bool {
        caseSensitive ?? false
    }
}

// Or use @Attribute(originalName:) for renames
@Attribute(originalName: "pattern") var regexPattern: String
```

**Phase impact:** Model changes — always add optionals, never remove, never change types.

---

## Summary: Phase-Specific Warnings

| Phase | Likely Pitfall | Severity | Mitigation |
|-------|---------------|----------|------------|
| Launch at Login | #1 Auto-enable rejection | CRITICAL | Use LaunchAtLogin.Toggle only |
| Launch at Login | #2 Wrong package | HIGH | Use LaunchAtLogin-Modern |
| Ignore Patterns | #4 Regex per-poll | MEDIUM | Cache compiled patterns |
| Ignore Patterns | #5 Invalid regex | MEDIUM | Real-time validation UI |
| Ignore Patterns | #6 ReDoS | LOW | Add matching timeout |
| Settings Storage | #8 Schema migration | CRITICAL | Implement recovery fallback |
| Settings Storage | #10 AppStorage types | HIGH | Never change key types |
| Hotkey Settings | #11 Shortcut conflicts | MEDIUM | Add reset, show current |
| All Settings | #13 Cached values | MEDIUM | Use AppStorage or observe |
| Model Changes | #14 Breaking data | CRITICAL | Only add optionals |

## Sources

- [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) - Official package documentation (HIGH confidence)
- [LaunchAtLogin-Legacy FAQ](https://github.com/sindresorhus/LaunchAtLogin-Legacy#faq) - Testing issues (HIGH confidence)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Hotkey package (HIGH confidence)
- [SwiftData Migration PR](https://github.com/Geoffe-Ga/wrist-arcana/pull/47) - Real-world crash fix (MEDIUM confidence)
- clipass codebase analysis - Current implementation (HIGH confidence)
