import SwiftUI
import SwiftData
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
}

@main
struct clipassApp: App {
    @State private var clipboardMonitor = ClipboardMonitor()
    @State private var transformEngine = TransformEngine()
    @State private var hookEngine = HookEngine()

    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
            ClipboardPopupContainer(monitor: clipboardMonitor, transformEngine: transformEngine, hookEngine: hookEngine)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(for: [ClipboardItem.self, TransformRule.self, Hook.self])
    }
}

struct ClipboardPopupContainer: View {
    var monitor: ClipboardMonitor
    var transformEngine: TransformEngine
    var hookEngine: HookEngine
    @Environment(\.modelContext) private var modelContext
    @State private var hasSetupMonitor = false

    var body: some View {
        ClipboardPopup(monitor: monitor)
            .onAppear {
                if !hasSetupMonitor {
                    monitor.setModelContext(modelContext)
                    transformEngine.setModelContext(modelContext)
                    hookEngine.setModelContext(modelContext)
                    monitor.setTransformEngine(transformEngine)
                    monitor.setHookEngine(hookEngine)
                    monitor.start()
                    setupHotkey()

                    // Create default rules on first launch
                    TransformEngine.createDefaultRulesIfNeeded(context: modelContext)

                    hasSetupMonitor = true
                }
            }
    }

    private func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleClipboard) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
