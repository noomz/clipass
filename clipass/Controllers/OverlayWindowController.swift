import AppKit
import SwiftUI

// MARK: - OverlayPanel

/// Non-activating floating panel that hosts the clipboard overlay UI.
/// Must be an NSPanel subclass — SwiftUI Window scenes always activate the app.
final class OverlayPanel: NSPanel {

    /// Set by OverlayWindowController.show() — used to guard against spurious resignKey calls.
    var shownAt: Date = .distantPast

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

        // Hide the titlebar entirely while keeping fullSizeContentView layout
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // Movement and appearance
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    // CRITICAL: NSPanel defaults canBecomeKey and canBecomeMain to false.
    // Without these overrides the panel cannot receive keyboard events or host @FocusState.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Click-outside and ESC dismissal entry point.
    /// Called by the system when the panel loses key status (another window gets focus, ESC, etc.)
    override func resignKey() {
        super.resignKey()

        // Pitfall 3 guard: if resignKey fires immediately after show (< 0.3 s) it is a
        // spurious call during initialization — ignore it to prevent flash-close.
        guard Date().timeIntervalSince(shownAt) > 0.3 else { return }

        orderOut(nil)

        // Notify the controller so it can restore the previous app's focus.
        NotificationCenter.default.post(name: .overlayDidResignKey, object: nil)
    }

    /// Belt-and-suspenders ESC handler at the NSPanel level.
    /// Fires when OverlaySearchField.keyDown does not consume the ESC key event
    /// (e.g., if the field loses first-responder before the key is processed).
    override func cancelOperation(_ sender: Any?) {
        OverlayWindowController.shared.hide()
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let overlayDidResignKey = Notification.Name("overlayDidResignKey")
}

// MARK: - OverlayWindowController

/// Singleton that owns the OverlayPanel and manages its show/hide/toggle lifecycle.
/// All methods must be called on the main actor.
@MainActor
final class OverlayWindowController {

    static let shared = OverlayWindowController()

    private let panel: OverlayPanel
    private var previousApp: NSRunningApplication?

    private init() {
        panel = OverlayPanel()

        // Inject the real overlay UI with model context and theme from AppServices.
        let overlayView = ClipboardOverlayView()
            .modelContext(AppServices.shared.modelContainer.mainContext)
            .environment(AppServices.shared.themeManager)
        panel.contentView = NSHostingView(rootView: overlayView)

        // Observe resignKey notification to restore focus to the previous app.
        NotificationCenter.default.addObserver(
            forName: .overlayDidResignKey,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restoreFocus()
            }
        }
    }

    // MARK: Toggle / Show / Hide

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        // Capture the frontmost app BEFORE making the panel key.
        // The panel is non-activating, so frontmostApplication won't change —
        // but we must capture it now before any activation could occur.
        previousApp = NSWorkspace.shared.frontmostApplication

        // Center the panel on the screen that contains the mouse cursor,
        // placed slightly above vertical center (Spotlight/Raycast convention).
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let origin = NSPoint(
                x: screenFrame.midX - panelSize.width / 2,
                y: screenFrame.midY + screenFrame.height * 0.1
            )
            panel.setFrameOrigin(origin)
        }

        panel.shownAt = Date()

        // Post notification BEFORE makeKeyAndOrderFront so the view resets its state
        // (clears search text, re-selects first item, re-focuses search field).
        NotificationCenter.default.post(name: Notification.Name("overlayWillShow"), object: nil)

        panel.makeKeyAndOrderFront(nil)

        // Focus is handled by OverlaySearchField.makeNSView() via DispatchQueue.main.async
        // calling window?.makeFirstResponder(field). No additional fallback needed here.
    }

    func hide() {
        panel.orderOut(nil)
        restoreFocus()
    }

    // MARK: Focus Restoration

    private func restoreFocus() {
        previousApp?.activate(options: .activateIgnoringOtherApps)
        previousApp = nil
    }

    // MARK: Paste and Hide

    /// Writes `content` to the system pasteboard, then hides the panel and restores focus.
    /// Plan 02 calls this from the Return key handler in ClipboardOverlayView.
    func pasteAndHide(content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        hide()
    }

    // MARK: Content Injection

    /// Replaces the panel's content view with a new SwiftUI view.
    /// Plan 02 calls this to inject the real ClipboardOverlayView.
    func setContentView<V: View>(_ view: V) {
        panel.contentView = NSHostingView(rootView: view)
    }
}
