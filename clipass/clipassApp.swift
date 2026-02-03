import SwiftUI

@main
struct clipassApp: App {
    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
            ClipboardPopup()
        }
        .menuBarExtraStyle(.window)
    }
}
