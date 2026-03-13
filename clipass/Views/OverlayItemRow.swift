import SwiftUI

/// Individual row view for an item in the overlay clipboard list.
/// Displays a truncated content preview, optional source app, and relative timestamp.
struct OverlayItemRow: View {

    let item: ClipboardItem

    private var previewText: String {
        DisplayFormatter.format(item.content, maxLength: 100, patterns: [])
    }

    private var relativeTime: String {
        let interval = Date().timeIntervalSince(item.timestamp)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                Text(previewText)
                    .lineLimit(1)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            HStack {
                if let sourceApp = item.sourceApp {
                    Text(sourceApp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // Clear background — List selection handles highlighting
        .background(Color.clear)
    }
}
