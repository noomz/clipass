import SwiftUI
import AppKit

struct HistoryItemRow: View {
    let item: ClipboardItem
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: copyToClipboard) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content.prefix(50) + (item.content.count > 50 ? "..." : ""))
                    .lineLimit(1)
                    .font(.body)
                    .foregroundColor(.primary)
                HStack {
                    if let sourceApp = item.sourceApp {
                        Text(sourceApp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(relativeTimeString(from: item.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Copy") {
                copyToClipboard()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
    }

    private func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
