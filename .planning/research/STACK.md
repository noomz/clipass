# Stack Research: v1.1 More Control

**Project:** clipass v1.1
**Researched:** 2026-02-06
**Focus:** Stack additions for settings/configuration features

## Executive Summary

v1.1 requires **one new dependency** (LaunchAtLogin-Modern) and **zero changes** to existing stack. The existing SwiftUI, SwiftData, and KeyboardShortcuts infrastructure handles all other requirements. Pattern matching uses Swift's built-in `Regex` (already in use for transforms).

## New Dependencies

### LaunchAtLogin-Modern (Required)

| Attribute | Value |
|-----------|-------|
| Package | `https://github.com/sindresorhus/LaunchAtLogin-Modern` |
| Version | v1.1.0 (released 2023-12-21) |
| Requirement | macOS 13+ (clipass targets macOS 14, ✓ compatible) |
| Purpose | "Start on login" toggle |

**Why this library:**
- **Drop-in SwiftUI component**: `LaunchAtLogin.Toggle()` is literally one line in Settings
- **Same author as KeyboardShortcuts**: Sindre Sorhus maintains both, consistent API patterns
- **Modern implementation**: Uses SMAppService (macOS 13+) which is the current Apple-recommended approach
- **Sandboxed & Mac App Store ready**: No deprecated APIs

**Integration:**
```swift
// Package.swift - add dependency
.package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.1.0"),

// SettingsView.swift - use component
import LaunchAtLogin

LaunchAtLogin.Toggle("Start at login")
```

**Confidence:** HIGH (verified via official GitHub, tested API stability)

## Existing Stack Extensions

### KeyboardShortcuts — Already Integrated

The app already uses KeyboardShortcuts v2.x for `Cmd+Shift+V`. For hotkey customization, just add the `Recorder` UI component:

```swift
// Already have:
extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
}

// Just add to Settings:
KeyboardShortcuts.Recorder("Global Hotkey:", name: .toggleClipboard)
```

**Current version:** 2.x (Package.swift says `from: "2.0.0"`)
**Latest version:** 2.4.0 (2025-09-18)

**Recommendation:** Keep current version constraint. No API changes needed, just add UI.

**Confidence:** HIGH (current code verified, README confirms Recorder usage)

### SwiftData — Already Integrated

Used for ClipboardItem, TransformRule, Hook models. For new settings:

**Settings that belong in SwiftData:**
- IgnoredApp patterns (user-created list of bundle IDs or regex patterns)
- ContentIgnorePattern rules (similar structure to TransformRule)
- SensitivePattern rules for redaction

**Why SwiftData for these:**
- Already using SwiftData for similar data (TransformRule has pattern + enabled + order)
- User creates/deletes multiple entries
- Benefits from same UI patterns as Rules/Hooks tabs

**Model additions needed:**
```swift
@Model
class IgnoredApp {
    var bundleIdPattern: String  // Exact match or regex
    var isRegex: Bool
    var isEnabled: Bool
}

@Model
class ContentIgnorePattern {
    var pattern: String  // Regex to skip storing
    var name: String
    var isEnabled: Bool
}

@Model
class SensitivePattern {
    var pattern: String  // Regex to detect sensitive content
    var name: String
    var redactWith: String  // e.g., "••••••" or "[REDACTED]"
    var isEnabled: Bool
}
```

**Confidence:** HIGH (matches existing patterns in codebase)

### UserDefaults — For Simple Preferences

For scalar settings that don't need complex storage:

| Setting | Type | Default | Storage |
|---------|------|---------|---------|
| maxHistoryItems | Int | 100 | UserDefaults |
| autoCleanupDays | Int | 30 (0 = disabled) | UserDefaults |
| previewTruncationLength | Int | 50 | UserDefaults |
| cleanInvisibleChars | Bool | true | UserDefaults |

**Implementation options:**

1. **Native `@AppStorage`** (Recommended):
```swift
@AppStorage("maxHistoryItems") var maxHistoryItems: Int = 100
@AppStorage("previewTruncationLength") var previewTruncationLength: Int = 50
```

2. **Sindre's Defaults library** (Alternative):
   - Version: 9.0.6 (2025-10-12)
   - Pros: Type-safe keys, observation, Codable support
   - Cons: Another dependency for simple preferences

**Recommendation:** Use native `@AppStorage` for scalar settings. No additional dependency needed. SwiftUI's built-in property wrapper handles:
- Automatic UI binding
- Persistence to UserDefaults
- Type safety

**Confidence:** HIGH (standard SwiftUI pattern)

### Swift Regex — Built-in, Already Used

The app already uses Swift's native `Regex` in TransformEngine:
```swift
let regex = try Regex(rule.pattern)
result = result.replacing(regex, with: rule.replacement)
```

For sensitive content detection and content ignore patterns, the same approach applies:
```swift
// Check if content matches any sensitive pattern
for pattern in sensitivePatterns {
    if let _ = content.firstMatch(of: try Regex(pattern.pattern)) {
        // Content is sensitive, redact in display
    }
}
```

**No additional libraries needed.** Swift's Regex is:
- Type-safe
- Fast (compiled once, reused)
- Full PCRE2 support

**Confidence:** HIGH (verified in existing codebase)

## Not Recommended

### Sindre's Defaults Library

**Why skip:**
- Only 4 scalar settings need UserDefaults storage
- `@AppStorage` handles this natively with zero dependencies
- Defaults library adds value for complex types (Codable enums, custom types) — not needed here
- Keep dependency count minimal

**Exception:** If future versions need complex serialization (e.g., storing enum arrays, custom types with migrations), reconsider.

### Separate Pattern Matching Library

**Why skip:**
- Swift's built-in `Regex` handles all use cases
- Already proven in TransformEngine
- No benefit from external libraries for text matching

### Service Management Framework Directly

**Why skip:**
- LaunchAtLogin-Modern wraps SMAppService cleanly
- Direct SMAppService usage requires more boilerplate
- Library handles edge cases (sandboxing, app relocation)

### Storing Settings in SwiftData

**Why skip for scalars:**
- SwiftData is overkill for `maxHistoryItems = 100`
- Requires model class, fetch descriptor, context injection
- UserDefaults via @AppStorage is 1 line

**Use SwiftData for:** Lists of patterns (ignored apps, content patterns, sensitive patterns)
**Use UserDefaults for:** Individual settings (limits, toggles, lengths)

## Package.swift Changes

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "clipass",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.1.0"),  // NEW
    ],
    targets: [
        .executableTarget(
            name: "clipass",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),  // NEW
            ],
            path: "clipass",
            exclude: ["Info.plist"]
        ),
    ]
)
```

## Integration Summary

| v1.1 Feature | Stack Component | New/Existing |
|--------------|-----------------|--------------|
| Start on login | LaunchAtLogin-Modern | **NEW** |
| Hotkey customization | KeyboardShortcuts.Recorder | Existing |
| Ignored app patterns | SwiftData model | Existing |
| Content ignore patterns | SwiftData model | Existing |
| Sensitive content redaction | SwiftData model + Swift Regex | Existing |
| History max items | @AppStorage | Existing |
| Auto-cleanup age | @AppStorage | Existing |
| Preview truncation | @AppStorage | Existing |
| Clean invisible chars | @AppStorage | Existing |

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| LaunchAtLogin-Modern | HIGH | Official GitHub verified, API documented |
| KeyboardShortcuts Recorder | HIGH | In existing dependency, README confirms UI |
| @AppStorage for settings | HIGH | Standard SwiftUI, no verification needed |
| SwiftData for patterns | HIGH | Matches existing TransformRule pattern |
| Swift Regex | HIGH | Already in production use in codebase |

## Sources

- LaunchAtLogin-Modern: https://github.com/sindresorhus/LaunchAtLogin-Modern (v1.1.0, verified 2026-02-06)
- KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts (v2.4.0, verified 2026-02-06)
- Defaults (evaluated, not recommended): https://github.com/sindresorhus/Defaults (v9.0.6)
- Existing clipass source: `/clipass/` directory in repo
