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
            contentRect: NSRect(origin: .zero, size: ClipboardBrowserStyle.overlaySize),
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

        // AppKit adds the hidden titlebar to contentRect, even though the hosted view fills the frame.
        setFrame(NSRect(origin: .zero, size: ClipboardBrowserStyle.overlaySize), display: false)
    }

    @discardableResult
    func host<Content: View>(_ content: Content) -> NSHostingView<Content> {
        let host = NSHostingView(rootView: content)
        // Let the panel size the full-bleed host, not AppKit's smaller content layout rect.
        host.sizingOptions = []
        host.safeAreaRegions = []
        contentView = host
        return host
    }

    func summon() {
        shownAt = Date()
        NotificationCenter.default.post(name: .overlayWillShow, object: self)
        makeKeyAndOrderFront(nil)
    }

    // CRITICAL: NSPanel defaults canBecomeKey and canBecomeMain to false.
    // Without these overrides the panel cannot receive keyboard events or host @FocusState.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Dismiss when the panel loses key status.
    override func resignKey() {
        super.resignKey()

        // Pitfall 3 guard: if resignKey fires immediately after show (< 0.3 s) it is a
        // spurious call during initialization — ignore it to prevent flash-close.
        guard Date().timeIntervalSince(shownAt) > 0.3 else { return }

        orderOut(nil)

        // Notify the controller so it can restore the previous app's focus.
        NotificationCenter.default.post(name: .overlayDidResignKey, object: nil)
    }

}

// MARK: - Notification name

extension Notification.Name {
    static let overlayWillShow = Notification.Name("overlayWillShow")
    static let overlayDidResignKey = Notification.Name("overlayDidResignKey")
}

// MARK: - OverlayWindowController

/// Singleton that owns the OverlayPanel and manages its show/hide/toggle lifecycle.
/// All methods must be called on the main actor.
@MainActor
final class OverlayWindowController {

    static let shared = OverlayWindowController()

    private static let originDefaultsKey = "overlayPanelOrigin"
    static let followsMouseScreenDefaultsKey = "overlayFollowsMouseScreen"

    /// Missing key means follow (the Settings default). `bool(forKey:)` is false when unset.
    static var followsMouseScreen: Bool {
        if UserDefaults.standard.object(forKey: followsMouseScreenDefaultsKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: followsMouseScreenDefaultsKey)
    }

    private let panel: OverlayPanel
    private var previousApp: NSRunningApplication?

    private init() {
        panel = OverlayPanel()

        // Inject the real overlay UI with model context and theme from AppServices.
        let overlayView = ClipboardOverlayView(panel: panel, monitor: AppServices.shared.clipboardMonitor)
            .modelContext(AppServices.shared.modelContainer.mainContext)
            .environment(AppServices.shared.themeManager)
        panel.host(overlayView)

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

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Skip while hidden — init and pre-show setFrame both fire didMove
                // at (0, 0), which must not become the "saved" position.
                guard self?.panel.isVisible == true else { return }
                self?.persistOrigin()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clampToVisibleIfNeeded()
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

        positionPanel()

        panel.summon()
    }

    func hide() {
        persistOrigin()
        panel.orderOut(nil)
        restoreFocus()
    }

    // MARK: Position

    private func positionPanel() {
        let size = panel.frame.size
        let panelSize = CGSize(
            width: size.width > 0 ? size.width : ClipboardBrowserStyle.overlaySize.width,
            height: size.height > 0 ? size.height : ClipboardBrowserStyle.overlaySize.height
        )
        let screens = NSScreen.screens
        let preferred = screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
        let frame = OverlayPositioning.frameForShow(
            panelSize: panelSize,
            savedOrigin: savedOrigin(),
            visibleFrames: screens.map(\.visibleFrame),
            preferredVisibleFrame: preferred?.visibleFrame ?? .zero,
            followsMouseScreen: Self.followsMouseScreen
        )
        panel.setFrame(frame, display: false)
    }

    private func clampToVisibleIfNeeded() {
        let current = panel.frame
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard let visible = visibleFrames.first(where: { $0.intersects(current) })
                ?? visibleFrames.first
        else { return }
        let clamped = OverlayPositioning.clamp(current, to: visible)
        guard clamped.origin != current.origin else { return }
        panel.setFrame(clamped, display: true)
        persistOrigin()
    }

    private func persistOrigin() {
        guard panel.isVisible else { return }
        let origin = panel.frame.origin
        guard origin != .zero else { return }
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: Self.originDefaultsKey)
    }

    private func savedOrigin() -> NSPoint? {
        guard let raw = UserDefaults.standard.string(forKey: Self.originDefaultsKey), !raw.isEmpty else {
            return nil
        }
        let point = NSPointFromString(raw)
        return point == .zero ? nil : point
    }

    // MARK: Focus Restoration

    private func restoreFocus() {
        previousApp?.activate(options: .activateIgnoringOtherApps)
        previousApp = nil
    }

    func copyAndHide(content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        hide()
    }

}
