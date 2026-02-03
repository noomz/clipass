import SwiftUI
import SwiftData
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
}

@main
struct clipassApp: App {
    @State private var clipboardMonitor = ClipboardMonitor()

    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
            ClipboardPopup(monitor: clipboardMonitor)
                .onAppear {
                    clipboardMonitor.start()
                    setupHotkey()
                }
        }
        .menuBarExtraStyle(.window)
        .modelContainer(for: ClipboardItem.self)
    }

    private func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleClipboard) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
