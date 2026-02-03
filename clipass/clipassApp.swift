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

    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
            ClipboardPopupContainer(monitor: clipboardMonitor, transformEngine: transformEngine)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(for: [ClipboardItem.self, TransformRule.self])
    }
}

struct ClipboardPopupContainer: View {
    var monitor: ClipboardMonitor
    var transformEngine: TransformEngine
    @Environment(\.modelContext) private var modelContext
    @State private var hasSetupMonitor = false

    var body: some View {
        ClipboardPopup(monitor: monitor)
            .onAppear {
                if !hasSetupMonitor {
                    monitor.setModelContext(modelContext)
                    transformEngine.setModelContext(modelContext)
                    monitor.setTransformEngine(transformEngine)
                    monitor.start()
                    setupHotkey()
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
