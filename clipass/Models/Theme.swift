import SwiftUI
import AppKit

// MARK: - Color Hex Initializer

extension Color {
    /// Initializes a Color from a CSS-style hex string (e.g., "#3b4252" or "3b4252").
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

// MARK: - Nord Palette Constants

extension Color {
    // Polar Night (backgrounds, dark surfaces)
    static let nordPolarNight0 = Color(hex: "#2e3440")  // nord0 — deepest background
    static let nordPolarNight1 = Color(hex: "#3b4252")  // nord1
    static let nordPolarNight2 = Color(hex: "#434c5e")  // nord2
    static let nordPolarNight3 = Color(hex: "#4c566a")  // nord3 — lighter dark

    // Snow Storm (text, light surfaces)
    static let nordSnowStorm4 = Color(hex: "#d8dee9")   // nord4
    static let nordSnowStorm5 = Color(hex: "#e5e9f0")   // nord5
    static let nordSnowStorm6 = Color(hex: "#eceff4")   // nord6 — brightest white

    // Frost (UI components, selection, accents)
    static let nordFrost7  = Color(hex: "#8fbcbb")      // nord7 — seafoam
    static let nordFrost8  = Color(hex: "#88c0d0")      // nord8 — light blue (primary UI)
    static let nordFrost9  = Color(hex: "#81a1c1")      // nord9 — slate blue
    static let nordFrost10 = Color(hex: "#5e81ac")      // nord10 — deeper blue

    // Aurora (status / accent colors)
    static let nordAurora11 = Color(hex: "#bf616a")     // nord11 — red
    static let nordAurora14 = Color(hex: "#a3be8c")     // nord14 — green
    static let nordAurora15 = Color(hex: "#b48ead")     // nord15 — purple/mauve
}

// MARK: - BackgroundMode

/// Declares the rendering strategy for the overlay background.
/// Each theme carries one of these to tell VisualEffectView which path to take.
enum BackgroundMode: Equatable {
    /// Standard vibrancy: NSVisualEffectView with the given material.
    case vibrancy(material: NSVisualEffectView.Material)

    /// Vibrancy with a semi-transparent tint overlay layered on top.
    case tintedVibrancy(material: NSVisualEffectView.Material, tint: Color, opacity: Double)

    /// Solid opaque background — bypasses NSVisualEffectView entirely.
    case solid

    /// Discriminator string for use as SwiftUI `.id()` — forces view recreation
    /// when the background mode type changes (vibrancy ↔ solid ↔ tinted).
    var discriminator: String {
        switch self {
        case .vibrancy(let m): return "vibrancy-\(m.rawValue)"
        case .tintedVibrancy(let m, _, _): return "tinted-\(m.rawValue)"
        case .solid: return "solid"
        }
    }
}

// MARK: - DividerStyle

/// Controls the visual weight of row dividers in the overlay list.
enum DividerStyle {
    /// Standard 1pt divider at the theme's dividerColor.
    case standard

    /// Heavier 2pt divider for themes that prefer strong structural separation.
    case thick

    /// No visible dividers.
    case none
}

// MARK: - ThemeID

/// Stable identifiers for the 5 built-in themes.
/// Stored as rawValue String in @AppStorage for persistence.
enum ThemeID: String, CaseIterable {
    case system    // Follows macOS system light/dark setting
    case dark      // Fixed dark, solid background
    case light     // Fixed light, vibrancy-based
    case midnight  // Purple/violet tinted dark aesthetic
    case nord      // Official Nord palette, solid background
}

// MARK: - Theme

/// All visual properties for a single theme.
/// Passed through the SwiftUI environment via ThemeManager so every overlay
/// view reads the same values without prop-drilling.
struct Theme {
    let id: ThemeID
    let name: String

    // Colors
    let overlayBackground: Color          // Used for solid mode; blended in tinted vibrancy
    let itemBackground: Color             // Selection highlight fill color
    let primaryText: Color
    let secondaryText: Color
    let dividerColor: Color
    let searchFieldBackground: Color
    let searchFieldText: Color
    let searchFieldPlaceholder: Color
    let accentColor: Color

    // Structure
    let cornerRadius: CGFloat             // Overlay panel corner radius
    let itemCornerRadius: CGFloat         // Per-row corner radius
    let itemVerticalPadding: CGFloat      // Top/bottom padding inside each row
    let dividerStyle: DividerStyle
    let titleFontWeight: Font.Weight
    let bodyFontSize: CGFloat

    // Background rendering strategy
    let backgroundMode: BackgroundMode

    /// Optional override for NSVisualEffectView.appearance.
    /// nil = follows system; .aqua = forced light; .darkAqua = forced dark.
    let forceAppearance: NSAppearance?
}

// MARK: - Theme Definitions

extension Theme {
    /// All 5 built-in theme definitions. ThemeManager indexes into this dictionary.
    static let themes: [ThemeID: Theme] = [

        // MARK: System
        // Follows macOS system appearance; vibrancy tinted with the user's accent color.
        // Colors use semantic system values so they adapt to light/dark automatically.
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
            backgroundMode: .tintedVibrancy(material: .hudWindow, tint: Color.accentColor, opacity: 0.15),
            forceAppearance: nil          // nil = follows system dark/light automatically
        ),

        // MARK: Dark
        // Fixed dark theme with a solid deep background. No vibrancy — the opaque
        // dark surface doesn't benefit from window content showing through.
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
            backgroundMode: .solid,
            forceAppearance: nil
        ),

        // MARK: Light
        // Fixed light theme with vibrancy forced to aqua appearance.
        // Works correctly even when the system is in Dark Mode.
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
            backgroundMode: .vibrancy(material: .hudWindow),
            forceAppearance: NSAppearance(named: .aqua)  // Always light vibrancy
        ),

        // MARK: Midnight
        // Purple/violet tinted dark aesthetic. Distinct from Dark via hue depth.
        // Tinted vibrancy gives the surface a moody blurred-purple character.
        // Sharper corners and thicker dividers for a more structured feel.
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
            cornerRadius: 10,
            itemCornerRadius: 4,
            itemVerticalPadding: 5,
            dividerStyle: .thick,
            titleFontWeight: .medium,
            bodyFontSize: NSFont.systemFontSize,
            backgroundMode: .tintedVibrancy(material: .hudWindow, tint: Color(hex: "#2d0a5e"), opacity: 0.6),
            forceAppearance: NSAppearance(named: .darkAqua)  // Always dark vibrancy base
        ),

        // MARK: Nord
        // Official Nord palette with solid polar night background.
        // Vibrancy would wash out the distinctive colors — solid is the correct choice.
        // Softer corners and slightly smaller type respect the Nord aesthetic.
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
            cornerRadius: 14,
            itemCornerRadius: 7,
            itemVerticalPadding: 7,
            dividerStyle: .standard,
            titleFontWeight: .regular,
            bodyFontSize: NSFont.systemFontSize - 0.5,
            backgroundMode: .solid,
            forceAppearance: nil
        )
    ]
}
