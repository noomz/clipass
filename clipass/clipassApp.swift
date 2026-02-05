import SwiftUI
import SwiftData
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
}

@main
struct clipassApp: App {
    private let modelContainer: ModelContainer
    private let clipboardMonitor: ClipboardMonitor
    private let transformEngine: TransformEngine
    private let hookEngine: HookEngine

    init() {
        // Create model container
        let container = try! ModelContainer(for: ClipboardItem.self, TransformRule.self, Hook.self)
        self.modelContainer = container

        // Create services
        let monitor = ClipboardMonitor()
        let transform = TransformEngine()
        let hook = HookEngine()

        // Set up contexts
        let context = container.mainContext
        monitor.setModelContext(context)
        transform.setModelContext(context)
        hook.setModelContext(context)
        monitor.setTransformEngine(transform)
        monitor.setHookEngine(hook)

        // Create default rules on first launch
        TransformEngine.createDefaultRulesIfNeeded(context: context)

        // Start monitoring immediately
        monitor.start()

        // Set up global hotkey
        KeyboardShortcuts.onKeyUp(for: .toggleClipboard) {
            NSApp.activate(ignoringOtherApps: true)
        }

        self.clipboardMonitor = monitor
        self.transformEngine = transform
        self.hookEngine = hook
    }

    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
            ClipboardPopup(monitor: clipboardMonitor)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)
    }
}
