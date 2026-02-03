import SwiftUI
import AppKit
import KeyboardShortcuts

struct ClipboardPopup: View {
    var monitor: ClipboardMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
                Text("Items: \(monitor.history.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            if monitor.history.isEmpty {
                VStack {
                    Spacer()
                    Text("No items yet")
                        .foregroundColor(.secondary)
                    Text("Copy some text to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(monitor.history.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.content.prefix(50) + (item.content.count > 50 ? "..." : ""))
                                    .lineLimit(1)
                                    .font(.body)
                                if let sourceApp = item.sourceApp {
                                    Text(sourceApp)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Divider()

            Button("Quit clipass") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding()
        }
        .frame(width: 300, height: 250)
    }
}
