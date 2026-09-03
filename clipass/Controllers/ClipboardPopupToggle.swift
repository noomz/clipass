import AppKit

/// Programmatically toggles the SwiftUI `MenuBarExtra` popup.
///
/// `MenuBarExtra` has no public show/hide API. The extra is an `NSStatusItem`
/// whose button lives on `NSStatusBarWindow`; clicking that button is how
/// the system opens the `.window`-style popup. `NSApp.activate()` is not
/// enough — clipass is an `LSUIElement` accessory app with no window to
/// bring forward.
enum ClipboardPopupToggle {
    /// Clicks the menu bar extra's status item button.
    /// Returns `false` if the status item could not be found.
    @MainActor
    @discardableResult
    static func toggle() -> Bool {
        guard let button = statusItemButton() else { return false }
        button.performClick(nil)
        return true
    }

    @MainActor
    static func statusItemButton() -> NSStatusBarButton? {
        let selector = NSSelectorFromString("statusItem")
        for window in NSApp.windows {
            guard window.className.contains("NSStatusBarWindow") else { continue }
            guard window.responds(to: selector),
                  let unmanaged = window.perform(selector),
                  let statusItem = unmanaged.takeUnretainedValue() as? NSStatusItem
            else { continue }
            // Inactive displays get an NSStatusItemReplicant; clicking the real item is enough.
            if String(describing: type(of: statusItem)).contains("Replicant") { continue }
            return statusItem.button
        }
        return nil
    }
}
