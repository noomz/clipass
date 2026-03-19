import SwiftUI

/// Individual row view for an item in the overlay clipboard list.
/// Displays a truncated content preview, optional source app, and relative timestamp.
/// Selection highlight is drawn inline (not via List) so it works when the search field
/// holds first-responder status and the list itself is never focused.
struct OverlayItemRow: View {

    @Environment(ThemeManager.self) private var themeManager

    let item: ClipboardItem
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var isEditing: Bool = false     // true when THIS row is currently being edited

    @State private var isHovered = false

    private var theme: Theme { themeManager.current }

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
                        .foregroundColor(.orange)  // Brand color — not themed
                }
                Text(previewText)
                    .lineLimit(1)
                    .font(.system(size: theme.bodyFontSize, weight: theme.titleFontWeight))
                    .foregroundColor(isSelected ? .white : theme.primaryText)

                Spacer()

                // Pencil icon — always present for hit-testing, opacity-driven visibility
                Button(action: { onEdit?() }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.85) : theme.accentColor)
                }
                .buttonStyle(.plain)
                .opacity((isSelected || isHovered) && !isEditing ? 1 : 0)
            }
            HStack {
                if let sourceApp = item.sourceApp {
                    Text(sourceApp)
                        .font(.caption2)
                        .foregroundColor(isSelected ? Color.white.opacity(0.75) : theme.secondaryText)
                }
                Spacer()
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundColor(isSelected ? Color.white.opacity(0.75) : theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, theme.itemVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.itemCornerRadius)
                .fill(isSelected ? theme.itemBackground : isHovered ? theme.primaryText.opacity(0.08) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleTap?()
        }
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            onTap?()
        })
    }
}
