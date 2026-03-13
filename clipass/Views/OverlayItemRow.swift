import SwiftUI

/// Individual row view for an item in the overlay clipboard list.
/// Displays a truncated content preview, optional source app, and relative timestamp.
/// Selection highlight is drawn inline (not via List) so it works when the search field
/// holds first-responder status and the list itself is never focused.
struct OverlayItemRow: View {

    let item: ClipboardItem
    var isSelected: Bool = false
    var onDoubleTap: (() -> Void)? = nil

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
                    .foregroundColor(isSelected ? .white : .primary)
            }
            HStack {
                if let sourceApp = item.sourceApp {
                    Text(sourceApp)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
                }
                Spacer()
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleTap?()
        }
    }
}
