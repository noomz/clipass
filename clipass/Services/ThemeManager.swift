import SwiftUI
import Observation

/// Manages the active theme and persists the user's selection across app restarts.
///
/// ThemeManager is a singleton created by AppServices and injected into both the
/// overlay NSHostingView and SettingsView via .environment(). Any view that reads
/// themeManager.current will re-render precisely when the theme changes.
///
/// Persistence note: @AppStorage does NOT support ThemeID directly (only String,
/// Int, Double, Bool, URL, Data). We store the rawValue String and convert on read
/// to avoid the Codable/RawRepresentable infinite-recursion trap (Research Pitfall 6).
@Observable
final class ThemeManager {

    /// The currently active theme. Views should read properties from this.
    var current: Theme

    /// Persisted theme ID stored as raw String to avoid @AppStorage type restrictions.
    @ObservationIgnored
    @AppStorage("selectedThemeID") private var storedThemeID: String = ThemeID.system.rawValue

    /// The currently selected ThemeID, tracked for observation.
    private(set) var selectedID: ThemeID = .system

    init() {
        // Initialize current from the persisted selection, falling back to system.
        let id = ThemeID(rawValue: UserDefaults.standard.string(forKey: "selectedThemeID") ?? ThemeID.system.rawValue) ?? .system
        selectedID = id
        current = Theme.themes[id] ?? Theme.themes[.system]!
    }

    /// Selects a new theme, persists the choice, and updates the active theme immediately.
    func select(_ id: ThemeID) {
        storedThemeID = id.rawValue
        selectedID = id
        current = Theme.themes[id] ?? Theme.themes[.system]!
    }
}
