# Phase 13: Theme System - Research

**Researched:** 2026-03-16
**Domain:** SwiftUI theming, NSVisualEffectView customization, @Observable state propagation, macOS AppKit appearance
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Theme palette & identity**
- Each theme has a strong, distinct personality — not subtle variations
- 5 options total: System (follows macOS light/dark) + 4 named themes (Dark, Light, Midnight, Nord)
- System is the default theme
- Nord uses the official Nord palette (nordtheme.com) hex values — Polar Night, Snow Storm, Frost, Aurora
- Midnight has a purple/violet-tinted dark aesthetic — distinct from Dark theme via hue, not just depth
- Dark and Light are independent fixed themes; System handles the auto-switching role

**Themed surfaces — full styling**
- All overlay elements are themed: background, text colors, selection highlight, accent color
- Search field fully themed: background, text color, placeholder color
- Dividers, bottom bar text, and item count all follow theme colors — no system colors leak through
- Per-theme corner radius (e.g., Nord softer, Midnight sharper)
- Per-theme typography: font weight and size can vary
- Per-theme spacing and divider style — each theme can feel structurally different

**Theme picker UX**
- New "Appearance" tab in Settings (7th tab)
- Mini overlay mockups as preview cards — each shows a miniature overlay with fake clipboard items
- Vertical list layout — stacked full-width cards, scrollable
- Instant apply — selecting a theme immediately applies it everywhere, no separate "Apply" button
- Selected theme shows a checkmark or highlight indicator

**Vibrancy interaction**
- Theme struct includes explicit `backgroundMode` flag: `.vibrancy`, `.solid`, or `.tintedVibrancy(opacity)`
- Each theme declares its own background strategy — not inferred from alpha
- System theme uses vibrancy tinted with the user's macOS accent color
- Dark/Light themes: Claude decides vibrancy vs solid based on palette
- Midnight/Nord themes: Claude decides based on what serves each palette best

### Claude's Discretion
- Tint strength per theme (strong vs subtle) for vibrancy-enabled themes
- Dark and Light vibrancy vs solid decision
- Midnight and Nord vibrancy vs solid decision
- Exact font sizes and weights per theme
- Exact spacing and divider styling per theme
- Exact corner radius values per theme
- Mini mockup fake data content
- Theme struct property names and architecture

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| THME-01 | App ships with 4 predefined themes (Dark, Light, Midnight, Nord) | Theme struct with hardcoded palettes; @Observable ThemeManager |
| THME-02 | User can select a theme from a new Appearance tab in Settings | AppearanceSettingsView as 7th Settings tab; instant-apply via ThemeManager |
| THME-03 | Selected theme persists across app restarts | @AppStorage with String RawRepresentable enum pattern |
| THME-04 | Theme picker shows live preview of each theme | Mini mockup cards using scaleEffect(.scaleToFit) on real overlay-alike SwiftUI view |
</phase_requirements>

---

## Summary

Phase 13 adds a complete theme system to the clipboard overlay. All theming is overlay-only — the menu bar popup is untouched. The implementation has three distinct layers: (1) a `Theme` value type and `ThemeManager` `@Observable` class that hold the palette and propagate changes, (2) updates to the overlay views to read theme values from the environment instead of hardcoded system colors, and (3) an `AppearanceSettingsView` with mini mockup preview cards.

The core challenge is propagating a mutable theme through `NSHostingView` inside an `NSPanel`. The `@Observable` pattern (iOS 17+ / macOS 14+) is the right tool: inject a `ThemeManager` instance via `.environment()` into the overlay's `NSHostingView` and into `SettingsView`. When `ThemeManager.current` changes, both consumers re-render automatically. Persistence uses `@AppStorage` with a `String`-backed `RawRepresentable` enum for the selected theme ID.

Vibrancy customization is the trickiest part. `NSVisualEffectView` can be forced into dark or light appearance by setting `view.appearance = NSAppearance(named: .darkAqua)` (or `.aqua`). Solid backgrounds simply bypass `NSVisualEffectView` and use a plain `NSView` with a solid `backgroundColor`. The `backgroundMode` enum on `Theme` drives which path `VisualEffectView` takes at render time.

**Primary recommendation:** Use `@Observable ThemeManager` injected via SwiftUI `.environment()`, with a `Theme` struct holding all per-theme values, persisted via `@AppStorage` string enum. Update `VisualEffectView` to accept a `backgroundMode` param and fork between vibrancy, tinted-vibrancy, and solid rendering paths.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Observation (`@Observable`) | macOS 14+ (Swift 5.9) | Observable ThemeManager class | Project already targets macOS 14+; leaner than ObservableObject — only views that read changed properties re-render |
| SwiftUI EnvironmentValues | Built-in | Theme injection down the view tree | Avoids threading theme through every init; matches existing modelContext injection pattern |
| AppKit `NSVisualEffectView` | Built-in | Vibrancy / solid background per theme | Already wrapped as `VisualEffectView`; needs `backgroundMode` extension |
| `@AppStorage` | Built-in | Persist selected theme ID | Already used for all other settings; zero friction |
| `NSAppearance` | Built-in | Force dark/light vibrancy direction | Required for fixed-dark and fixed-light vibrancy themes independent of system setting |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI `scaleEffect` | Built-in | Shrink full-size overlay mockup into a mini card | Mini theme preview cards — render real view at full size, scale it down |
| SwiftUI `colorScheme` modifier | Built-in | Coerce System theme preview card to show correct light/dark | Only needed in the Settings preview card for System theme |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@Observable` ThemeManager | `ObservableObject` + `@EnvironmentObject` | ObservableObject triggers all observing views to re-render regardless of which property changed; @Observable is more precise and is the modern replacement |
| `@AppStorage` string enum | Custom UserDefaults serialization | @AppStorage + RawRepresentable is simpler, idiomatic, and less error-prone |
| `NSAppearance(named:)` on VisualEffectView | Overriding `NSApp.appearance` | App-level appearance would style the Settings window and menu bar popup too — must stay at view level |

**No external packages needed.** Everything required is in the standard SDK.

---

## Architecture Patterns

### Recommended Project Structure
```
clipass/
├── Models/
│   └── Theme.swift           # Theme struct + ThemeID enum + all 5 theme definitions
├── Services/ (or Models/)
│   └── ThemeManager.swift    # @Observable class, @AppStorage persistence
├── Views/
│   ├── ClipboardOverlayView.swift   # Read theme from @Environment
│   ├── OverlayItemRow.swift         # Replace Color.accentColor / Color.primary
│   ├── OverlaySearchField.swift     # Apply theme colors in updateNSView
│   ├── VisualEffectView.swift       # Accept BackgroundMode param
│   └── AppearanceSettingsView.swift # New: Appearance tab with mini cards
```

### Pattern 1: Theme Value Type + ThemeManager Observable

**What:** A `Theme` struct carries all visual properties. A `ThemeManager` `@Observable` class holds the active theme and persists the selection. Both the overlay's `NSHostingView` and Settings receive the same `ThemeManager` instance.

**When to use:** Any shared mutable state that must propagate to multiple independent SwiftUI trees (overlay panel + settings window).

```swift
// Source: Observation framework + SwiftUI EnvironmentValues pattern
// Theme.swift

struct Theme {
    let id: ThemeID
    let name: String

    // Colors
    let overlayBackground: Color   // Used for solid mode; also blended in tinted vibrancy
    let itemBackground: Color      // Selection highlight fill
    let primaryText: Color
    let secondaryText: Color
    let dividerColor: Color
    let searchFieldBackground: Color
    let searchFieldText: Color
    let searchFieldPlaceholder: Color
    let accentColor: Color

    // Structure
    let cornerRadius: CGFloat
    let itemCornerRadius: CGFloat
    let itemVerticalPadding: CGFloat
    let dividerStyle: DividerStyle
    let titleFontWeight: Font.Weight
    let bodyFontSize: CGFloat

    // Background rendering strategy
    let backgroundMode: BackgroundMode
}

enum BackgroundMode {
    case vibrancy(material: NSVisualEffectView.Material)
    case tintedVibrancy(material: NSVisualEffectView.Material, tint: Color, opacity: Double)
    case solid
}

enum DividerStyle {
    case standard        // 1pt at primary divider color
    case thick           // 2pt slightly darker
    case none
}

enum ThemeID: String, CaseIterable {
    case system, dark, light, midnight, nord
}
```

```swift
// ThemeManager.swift
import Observation

@Observable
final class ThemeManager {
    var current: Theme = Theme.themes[.system]!

    @ObservationIgnored
    @AppStorage("selectedThemeID") private var storedThemeID: String = ThemeID.system.rawValue

    init() {
        if let id = ThemeID(rawValue: storedThemeID) {
            current = Theme.themes[id] ?? Theme.themes[.system]!
        }
    }

    func select(_ id: ThemeID) {
        storedThemeID = id.rawValue
        current = Theme.themes[id] ?? Theme.themes[.system]!
    }
}
```

### Pattern 2: Environment Injection into NSHostingView

**What:** Pass the `ThemeManager` singleton through SwiftUI `.environment()` into both the overlay hosting view and SettingsView at the app root.

**When to use:** Any time you need a reference-type observable to be accessible throughout a SwiftUI tree hosted in NSHostingView.

```swift
// OverlayWindowController.swift — update init:
// Source: SwiftUI environment injection pattern, apple docs

let overlayView = ClipboardOverlayView()
    .modelContext(AppServices.shared.modelContainer.mainContext)
    .environment(AppServices.shared.themeManager)   // inject ThemeManager
panel.contentView = NSHostingView(rootView: overlayView)
```

```swift
// clipassApp.swift — update Settings window:
Window("Settings", id: "settings") {
    SettingsView()
        .modelContext(services.modelContainer.mainContext)
        .environment(services.themeManager)
}
```

```swift
// OverlayItemRow.swift — consuming theme:
struct OverlayItemRow: View {
    @Environment(ThemeManager.self) private var themeManager
    // Replace Color.accentColor → themeManager.current.accentColor
    // Replace Color.primary → themeManager.current.primaryText
}
```

### Pattern 3: VisualEffectView with BackgroundMode

**What:** Fork `VisualEffectView` rendering based on `backgroundMode` from the current theme. Solid mode uses a plain colored rectangle; vibrancy modes use `NSVisualEffectView` with optional tint overlay.

**When to use:** Whenever the theme transitions between vibrancy and solid backgrounds.

```swift
// VisualEffectView.swift — updated

struct VisualEffectView: NSViewRepresentable {
    var backgroundMode: BackgroundMode

    func makeNSView(context: Context) -> NSView {
        switch backgroundMode {
        case .vibrancy(let material):
            return makeVibrantView(material: material, tint: nil, opacity: 0, forceAppearance: nil)
        case .tintedVibrancy(let material, let tint, let opacity):
            return makeVibrantView(material: material, tint: tint, opacity: opacity, forceAppearance: nil)
        case .solid:
            return NSView()  // background color set in updateNSView via layer
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update colors / material as theme changes
    }

    private func makeVibrantView(material: NSVisualEffectView.Material,
                                  tint: Color?, opacity: Double,
                                  forceAppearance: NSAppearance?) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active   // CRITICAL: required under .accessory activation policy
        if let appearance = forceAppearance {
            view.appearance = appearance   // Force dark or light
        }
        return view
    }
}
```

**Forcing dark/light appearance on NSVisualEffectView:**
```swift
// Force vibrancy to always render dark (for Dark and Midnight fixed themes)
view.appearance = NSAppearance(named: .darkAqua)

// Force vibrancy to always render light (for Light fixed theme)
view.appearance = NSAppearance(named: .aqua)

// System theme: leave nil — inherits from system
view.appearance = nil
```

### Pattern 4: @AppStorage with String Enum (no RawRepresentable wrapping needed)

**What:** `ThemeID` is a `String` enum. `@AppStorage` natively supports `String`-backed enums as of Swift/SwiftUI. No `RawRepresentable` bridging required.

**When to use:** Simple enum with String raw values — the easiest `@AppStorage` pattern.

```swift
// @AppStorage supports RawRepresentable enums where RawValue: String directly
@AppStorage("selectedThemeID") private var storedThemeID: String = ThemeID.system.rawValue
// Then manually map: ThemeID(rawValue: storedThemeID)
```

Note: `@AppStorage` does NOT support `ThemeID` directly (only `String`, `Int`, `Double`, `Bool`, `URL`, `Data`). Store the `rawValue` string and convert on read. This avoids the Codable/RawRepresentable infinite-recursion trap.

### Pattern 5: Mini Mockup Preview Cards

**What:** Render a full-resolution `MiniOverlayMockup` view (the shape of the real overlay) then apply `.scaleEffect` to shrink it into a card. The mockup has no live data — it uses hardcoded fake clipboard items.

**When to use:** Theme picker preview cards — you want the preview to look exactly like the real overlay.

```swift
struct ThemePreviewCard: View {
    let theme: Theme
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            MiniOverlayMockup(theme: theme)
                .frame(width: 640, height: 400)
                .scaleEffect(0.28, anchor: .topLeading)
                // scaleEffect doesn't change layout size — clamp with frame:
                .frame(width: 640 * 0.28, height: 400 * 0.28)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius * 0.28))

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        )
    }
}
```

**Important scaleEffect layout note:** `.scaleEffect` scales rendering only, NOT layout size. The view still occupies its original frame in the layout engine. You must follow with `.frame(width: scaledW, height: scaledH)` to collapse the layout frame to the rendered size.

### Anti-Patterns to Avoid

- **Setting `NSApp.appearance` for theming:** This would apply dark/light to the entire app including Settings and the menu bar popup. Must stay at view level (`nsVisualEffectView.appearance`).
- **Using `@EnvironmentObject` instead of `@Observable` environment injection:** The project targets macOS 14+, which supports the Observation framework. `@Observable` with `.environment(_:)` is the modern, preferred pattern.
- **Encoding ThemeID as Codable for @AppStorage:** The Codable+RawRepresentable combination on `@AppStorage` can cause infinite recursion in the encoder. Store `rawValue: String` directly.
- **Using deprecated NSVisualEffectView materials:** `.light`, `.dark`, `.mediumLight`, `.ultraDark` are deprecated since macOS 10.14. Use `.hudWindow`, `.popover`, `.sidebar`, `.underWindowBackground` etc.
- **Applying `.scaleEffect` without collapsing the layout frame:** The view will still consume the original 640×400 of layout space, breaking the card list.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Observable theme propagation | Custom NotificationCenter theme events | `@Observable` + SwiftUI `.environment()` | Observation framework gives precise per-property change tracking; no boilerplate |
| Persistence | Custom JSON file in Application Support | `@AppStorage` with String rawValue | Already used for all settings; zero-friction |
| Force dark/light appearance | Manually setting every color for dark mode | `view.appearance = NSAppearance(named: .darkAqua)` | Single property sets entire subtree appearance for vibrancy |
| Miniature overlay preview | Separate "mini" component with duplicated layout logic | `.scaleEffect` on the real mockup view | Guaranteed to match actual overlay proportions; one source of truth |

**Key insight:** The Observation framework eliminates all the threading and diffing complexity of manual theme notification systems. Any view that reads `themeManager.current.anyProperty` will re-render precisely when that property changes — nothing more, nothing less.

---

## Common Pitfalls

### Pitfall 1: NSVisualEffectView appearance not respected
**What goes wrong:** Setting `view.appearance = NSAppearance(named: .darkAqua)` on the `NSVisualEffectView` has no effect — vibrancy still follows system appearance.
**Why it happens:** The appearance is set before the view is added to the window's view hierarchy. NSAppearance inheritance resolution happens at display time.
**How to avoid:** Set `appearance` in `updateNSView`, not `makeNSView`. Alternatively set it after `contentView` is assigned.
**Warning signs:** Dark theme shows as light-vibrancy when system is in light mode.

### Pitfall 2: scaleEffect breaks layout in ScrollView
**What goes wrong:** The mini preview cards in the theme picker overlap or have huge gaps between them.
**Why it happens:** `.scaleEffect` scales rendering but not layout. The card still occupies 640×400 layout pixels.
**How to avoid:** Always follow `.scaleEffect(factor)` with `.frame(width: originalW * factor, height: originalH * factor)` to collapse layout size.
**Warning signs:** Cards appear correctly sized visually but have invisible empty space between them.

### Pitfall 3: ThemeManager not shared between overlay and Settings
**What goes wrong:** Selecting a theme in Settings does not update the visible overlay.
**Why it happens:** Two separate `ThemeManager` instances are created — one for overlay, one for Settings.
**How to avoid:** Create a single `ThemeManager` instance in `AppServices.shared` and inject it into both the overlay `NSHostingView` and the Settings `Window` scene via `.environment()`.
**Warning signs:** Theme changes in Settings require app restart to show in overlay.

### Pitfall 4: @Observable property in NSHostingView not updating
**What goes wrong:** The overlay does not re-render when `themeManager.current` changes.
**Why it happens:** `NSHostingView` needs the `@Observable` object in the SwiftUI environment, not passed as a stored property. If you wrap it as a constant `let themeManager = ...` in the view struct, the Observation framework cannot track it.
**How to avoid:** Use `@Environment(ThemeManager.self) private var themeManager` inside the view. Inject via `.environment(themeManager)` at the `NSHostingView` creation site.
**Warning signs:** First theme selection works, subsequent ones don't without restarting the overlay panel.

### Pitfall 5: NSVisualEffectView.state = .active forgotten when updating
**What goes wrong:** After a theme change rebuilds or reconfigures the `NSVisualEffectView`, blur stops rendering and shows as flat gray.
**Why it happens:** When `updateNSView` reassigns `material`, the `state` property is not re-set. `.active` must be set on every reconfiguration because it's not part of the material assignment.
**Why it matters:** This is an established project gotcha documented in STATE.md — "NSVisualEffectView state=.active required for .accessory policy blur rendering."
**How to avoid:** Always include `view.state = .active` in `updateNSView` alongside any material update.

### Pitfall 6: ThemeID @AppStorage stores ThemeID directly
**What goes wrong:** `@AppStorage("selectedThemeID") var selected: ThemeID = .system` compiles but crashes at runtime.
**Why it happens:** `@AppStorage` requires types that are `Int`, `String`, `Double`, `Bool`, `URL`, or `Data`, or `RawRepresentable` where `RawValue` is one of those. The Codable+RawRepresentable pattern for custom types causes infinite recursion in JSONEncoder.
**How to avoid:** Store `@AppStorage("selectedThemeID") private var storedID: String = ThemeID.system.rawValue`, then convert: `ThemeID(rawValue: storedID) ?? .system`.

---

## Code Examples

### Nord Palette Constants (verified from nordtheme.com)
```swift
// Source: https://www.nordtheme.com/docs/colors-and-palettes
extension Color {
    // Polar Night (backgrounds, dark surfaces)
    static let nordPolarNight0 = Color(hex: "#2e3440") // nord0 - deepest background
    static let nordPolarNight1 = Color(hex: "#3b4252") // nord1
    static let nordPolarNight2 = Color(hex: "#434c5e") // nord2
    static let nordPolarNight3 = Color(hex: "#4c566a") // nord3 - lighter dark

    // Snow Storm (text, light surfaces)
    static let nordSnowStorm4 = Color(hex: "#d8dee9") // nord4
    static let nordSnowStorm5 = Color(hex: "#e5e9f0") // nord5
    static let nordSnowStorm6 = Color(hex: "#eceff4") // nord6 - brightest white

    // Frost (UI components, selection, accents)
    static let nordFrost7  = Color(hex: "#8fbcbb") // nord7 - seafoam
    static let nordFrost8  = Color(hex: "#88c0d0") // nord8 - light blue (primary UI)
    static let nordFrost9  = Color(hex: "#81a1c1") // nord9 - slate blue
    static let nordFrost10 = Color(hex: "#5e81ac") // nord10 - deeper blue

    // Aurora (status colors — accent)
    static let nordAurora11 = Color(hex: "#bf616a") // nord11 - red
    static let nordAurora14 = Color(hex: "#a3be8c") // nord14 - green (good for selection)
    static let nordAurora15 = Color(hex: "#b48ead") // nord15 - purple/mauve
}

// Hex initializer (not in SDK, add as extension)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >>  8) & 0xFF) / 255.0
        let b = Double( int        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

### Theme Definitions (recommended palette choices)
```swift
extension Theme {
    static let themes: [ThemeID: Theme] = [
        .system: Theme(
            id: .system,
            name: "System",
            overlayBackground: .clear,
            itemBackground: Color.accentColor,
            primaryText: .primary,
            secondaryText: .secondary,
            dividerColor: Color.primary.opacity(0.15),
            searchFieldBackground: Color.primary.opacity(0.06),
            searchFieldText: .primary,
            searchFieldPlaceholder: Color.secondary,
            accentColor: Color.accentColor,
            cornerRadius: 12,
            itemCornerRadius: 6,
            itemVerticalPadding: 6,
            dividerStyle: .standard,
            titleFontWeight: .regular,
            bodyFontSize: NSFont.systemFontSize,
            backgroundMode: .vibrancy(material: .hudWindow)
            // Note: nil appearance = follows system dark/light automatically
        ),
        .dark: Theme(
            id: .dark,
            name: "Dark",
            overlayBackground: Color(hex: "#1e1e1e"),
            itemBackground: Color(hex: "#3a7bd5"),
            primaryText: Color(hex: "#f0f0f0"),
            secondaryText: Color(hex: "#888888"),
            dividerColor: Color(hex: "#333333"),
            searchFieldBackground: Color(hex: "#2a2a2a"),
            searchFieldText: Color(hex: "#f0f0f0"),
            searchFieldPlaceholder: Color(hex: "#555555"),
            accentColor: Color(hex: "#3a7bd5"),
            cornerRadius: 12,
            itemCornerRadius: 6,
            itemVerticalPadding: 6,
            dividerStyle: .standard,
            titleFontWeight: .regular,
            bodyFontSize: NSFont.systemFontSize,
            backgroundMode: .solid
            // Solid: dark background doesn't benefit from vibrancy
        ),
        .light: Theme(
            id: .light,
            name: "Light",
            overlayBackground: Color(hex: "#f5f5f5"),
            itemBackground: Color(hex: "#0066CC"),
            primaryText: Color(hex: "#1a1a1a"),
            secondaryText: Color(hex: "#666666"),
            dividerColor: Color(hex: "#dedede"),
            searchFieldBackground: Color(hex: "#ebebeb"),
            searchFieldText: Color(hex: "#1a1a1a"),
            searchFieldPlaceholder: Color(hex: "#aaaaaa"),
            accentColor: Color(hex: "#0066CC"),
            cornerRadius: 12,
            itemCornerRadius: 6,
            itemVerticalPadding: 6,
            dividerStyle: .standard,
            titleFontWeight: .regular,
            bodyFontSize: NSFont.systemFontSize,
            backgroundMode: .vibrancy(material: .hudWindow)
            // forceAppearance: NSAppearance(named: .aqua) — set in VisualEffectView for light-forced vibrancy
        ),
        .midnight: Theme(
            id: .midnight,
            name: "Midnight",
            overlayBackground: Color(hex: "#1a0a2e"),
            itemBackground: Color(hex: "#7b4fd4"),
            primaryText: Color(hex: "#e8e0f5"),
            secondaryText: Color(hex: "#8b7aaa"),
            dividerColor: Color(hex: "#2d1a52"),
            searchFieldBackground: Color(hex: "#251040"),
            searchFieldText: Color(hex: "#e8e0f5"),
            searchFieldPlaceholder: Color(hex: "#6b5a8a"),
            accentColor: Color(hex: "#9d6ff5"),
            cornerRadius: 10,   // sharper per decision
            itemCornerRadius: 4,
            itemVerticalPadding: 5,
            dividerStyle: .thick,
            titleFontWeight: .medium,
            bodyFontSize: NSFont.systemFontSize,
            backgroundMode: .tintedVibrancy(material: .hudWindow, tint: Color(hex: "#2d0a5e"), opacity: 0.6)
        ),
        .nord: Theme(
            id: .nord,
            name: "Nord",
            overlayBackground: .nordPolarNight0,
            itemBackground: .nordFrost9,
            primaryText: .nordSnowStorm5,
            secondaryText: .nordPolarNight3,
            dividerColor: .nordPolarNight2,
            searchFieldBackground: .nordPolarNight1,
            searchFieldText: .nordSnowStorm5,
            searchFieldPlaceholder: .nordPolarNight3,
            accentColor: .nordFrost8,
            cornerRadius: 14,   // softer per decision
            itemCornerRadius: 7,
            itemVerticalPadding: 7,
            dividerStyle: .standard,
            titleFontWeight: .regular,
            bodyFontSize: NSFont.systemFontSize - 0.5,
            backgroundMode: .solid
            // Nord's distinct polar palette reads better without vibrancy washing it out
        )
    ]
}
```

### AppearanceSettingsView skeleton
```swift
struct AppearanceSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(ThemeID.allCases, id: \.self) { id in
                    let theme = Theme.themes[id]!
                    ThemePreviewCard(theme: theme, isSelected: themeManager.current.id == id)
                        .onTapGesture { themeManager.select(id) }
                }
            }
            .padding()
        }
    }
}
```

### Updating OverlaySearchField for theme colors
```swift
// In OverlaySearchField.updateNSView — apply theme NSTextField colors via AppKit
func updateNSView(_ nsView: InterceptingTextField, context: Context) {
    // Existing text/callback sync...
    nsView.textColor = NSColor(theme.searchFieldText)
    // NSTextField placeholder color via attributed string
    let attrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor(theme.searchFieldPlaceholder)
    ]
    nsView.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: attrs)
    // Background (for solid/tinted modes)
    if case .solid = theme.backgroundMode {
        nsView.drawsBackground = true
        nsView.backgroundColor = NSColor(theme.searchFieldBackground)
    } else {
        nsView.drawsBackground = false
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject` + `@EnvironmentObject` | `@Observable` + `.environment(_:)` | macOS 14 / Swift 5.9 (2023) | Views only re-render when accessed properties change; less boilerplate |
| Custom `EnvironmentKey` boilerplate | `@Entry` macro on `EnvironmentValues` | Xcode 16 / macOS 15 SDK (2024) | 2-line environment value declaration; but project targets macOS 14, so use traditional key or @Observable injection |
| NSVisualEffectView `.dark` / `.light` materials | Deprecated; use `.hudWindow`, `.popover`, `.sidebar` + `NSAppearance` | macOS 10.14+ | Don't use deprecated material names |

**Deprecated/outdated:**
- `NSVisualEffectView.Material.dark / .light / .mediumLight / .ultraDark`: Deprecated since macOS 10.14. Use semantic materials + `view.appearance = NSAppearance(named: .darkAqua/.aqua)`.
- `@Entry` macro: Available only on macOS 15+ SDK / Xcode 16. The project targets macOS 14 minimum — use the traditional `EnvironmentKey` protocol or `@Observable` injection directly. `@Observable` injection does NOT require `@Entry`.

---

## Open Questions

1. **Tinted vibrancy rendering fidelity for Midnight theme**
   - What we know: `NSVisualEffectView` with `.hudWindow` material + forced dark appearance gives a blur. Adding a tint overlay `CALayer` above it gives the purple cast.
   - What's unclear: Whether a semi-transparent SwiftUI `Color` overlay on top of a dark `NSVisualEffectView` achieves the right look vs. the private CALayer tinting API.
   - Recommendation: Start with a SwiftUI `Color` overlay (`.tintedVibrancy` mode renders `VisualEffectView` + a `Color` rectangle on top at the specified opacity). If it looks washed out, explore `CALayer` tinting. Do not use private APIs.

2. **System theme + macOS accent color tint**
   - What we know: The user decision says System uses vibrancy tinted with the macOS accent color. `NSColor.controlAccentColor` provides the current accent.
   - What's unclear: Whether SwiftUI `Color.accentColor` (which maps to `controlAccentColor`) applied as a tint overlay on `.hudWindow` vibrancy gives a perceptible but not overwhelming tint.
   - Recommendation: Use `.tintedVibrancy(material: .hudWindow, tint: Color.accentColor, opacity: 0.15)` for System theme as the starting point. Adjust opacity if too strong or invisible.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None — no test target exists in Package.swift |
| Config file | None |
| Quick run command | `swift build` (compile validation only) |
| Full suite command | `swift build` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THME-01 | 4 predefined themes exist with correct palette values | manual | `swift build` (compile check) | ❌ Wave 0 — no test target |
| THME-02 | Appearance tab visible in Settings, theme selection applies instantly | manual-only | Manual UI verification | N/A |
| THME-03 | Selected theme survives app restart | manual-only | Manual — relaunch app | N/A |
| THME-04 | Theme picker shows mini preview cards that match each theme | manual-only | Manual UI verification | N/A |

### Sampling Rate
- **Per task commit:** `swift build` — confirms no compile errors
- **Per wave merge:** `swift build` — same (no automated tests)
- **Phase gate:** Manual UI verification of all 4 success criteria before `/gsd:verify-work`

### Wave 0 Gaps
- No test target exists in Package.swift — adding one is out of scope for this phase (no test infrastructure was established in prior phases)
- All theme correctness and UI behavior requires manual verification

---

## Sources

### Primary (HIGH confidence)
- [nordtheme.com/docs/colors-and-palettes](https://www.nordtheme.com/docs/colors-and-palettes) — Official Nord hex values (nord0–nord15) verified
- Existing project source files — `VisualEffectView.swift`, `OverlayWindowController.swift`, `SettingsView.swift`, `OverlayItemRow.swift`, `OverlaySearchField.swift`, `clipassApp.swift` — all read directly

### Secondary (MEDIUM confidence)
- [avanderlee.com — @Entry macro for custom environment values](https://www.avanderlee.com/swiftui/entry-macro-custom-environment-values/) — @Entry confirmed macOS 15+/Xcode 16; @Observable injection pattern confirmed
- [nilcoalescing.com — Saving custom Codable types in AppStorage](https://nilcoalescing.com/blog/SaveCustomCodableTypesInAppStorageOrSceneStorage/) — RawRepresentable pattern confirmed, infinite-recursion trap documented
- [hackingwithswift.com — Sharing @Observable objects through SwiftUI environment](https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment) — @Observable + .environment() injection pattern confirmed
- [oskargroth.com — Reverse Engineering NSVisualEffectView](https://oskargroth.com/blog/reverse-engineering-nsvisualeffectview) — Tint layer CALayer architecture, lightenBlendMode for dark materials

### Tertiary (LOW confidence — needs in-app validation)
- NSAppearance(named: .darkAqua) forcing on NSVisualEffectView: Pattern is well-known across multiple sources but the STATE.md blocker notes that vibrancy rendering with .accessory activation policy needs in-app validation
- Tinted vibrancy for Midnight theme via SwiftUI Color overlay: Not confirmed by official docs; recommended as simpler alternative to private CALayer API

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are built-in SDK; @Observable is confirmed for macOS 14+
- Architecture: HIGH — patterns match existing project conventions; injection sites confirmed by reading source
- Pitfalls: HIGH for items inherited from STATE.md decisions; MEDIUM for novel vibrancy tinting specifics
- Nord palette values: HIGH — verified against official nordtheme.com documentation

**Research date:** 2026-03-16
**Valid until:** 2026-06-16 (stable APIs)
