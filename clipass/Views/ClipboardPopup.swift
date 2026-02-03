import SwiftUI
import AppKit

struct ClipboardPopup: View {
    var body: some View {
        VStack {
            Text("Clipboard History")
                .font(.headline)
                .padding()

            Spacer()

            Divider()

            Button("Quit clipass") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding()
        }
        .frame(width: 300, height: 200)
    }
}
