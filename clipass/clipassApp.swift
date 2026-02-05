import SwiftUI
import SwiftData
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
}

@main
struct clipassApp: App {
    let modelContainer: ModelContainer
    let clipboardMonitor: ClipboardMonitor
    let transformEngine: TransformEngine
    let hookEngine: HookEngine

    init() {
        // Create shared ModelContainer
        let container = try! ModelContainer(for: ClipboardItem.self, TransformRule.self, Hook.self)
        self.modelContainer = container

        // Create services with the shared context
        let context = ModelContext(container)
        let monitor = ClipboardMonitor()
        let transform = TransformEngine()
        let hook = HookEngine()

        monitor.setModelContext(context)
        transform.setModelContext(context)
        hook.setModelContext(context)
        monitor.setTransformEngine(transform)
        monitor.setHookEngine(hook)

        // Create default rules on first launch
        TransformEngine.createDefaultRulesIfNeeded(context: context)

        self.clipboardMonitor = monitor
        self.transformEngine = transform
        self.hookEngine = hook

        // Start monitoring immediately
        monitor.start()

        // Setup global hotkey
        KeyboardShortcuts.onKeyUp(for: .toggleClipboard) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
            ClipboardPopup(monitor: clipboardMonitor)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)
    }
}
