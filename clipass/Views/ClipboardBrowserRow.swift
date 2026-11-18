import SwiftUI

struct ClipboardBrowserRow<Trailing: View>: View {
    let item: ClipboardItem
    let previewText: String
    let tags: [TagInfo]
    let isSelected: Bool
    let isHovered: Bool
    @ViewBuilder var trailing: Trailing
    @Environment(\.clipboardBrowserStyle) private var style

    private var foreground: Color { isSelected ? style.selectedInk : style.ink }
    private var metadata: Color { isSelected ? style.selectedInk.opacity(0.9) : style.muted }

    var body: some View {
        let iconShape = RoundedRectangle(cornerRadius: 6)
        let iconSize: CGFloat = style.compact ? 24 : 28
        let source = item.sourceAppDisplayName
        HStack(spacing: style.compact ? 8 : 12) {
            Image(systemName: symbol)
                .font(.system(size: style.compact ? 13 : 15))
                .foregroundStyle(isSelected ? foreground : style.iconInk)
                .frame(width: iconSize, height: iconSize)
                .background(isSelected ? foreground.opacity(0.10) : style.iconFill, in: iconShape)
                .overlay { iconShape.strokeBorder(isSelected ? foreground.opacity(0.32) : style.controlBorder) }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(previewText)
                    .font(.system(size: style.compact ? 12 : style.theme?.bodyFontSize ?? 13,
                                  weight: style.theme?.id == .system ? .medium : style.theme?.titleFontWeight ?? .medium))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                if source != nil || (!style.compact && !tags.isEmpty) {
                    HStack(spacing: 6) {
                        if let source { Text(source) }
                        if !style.compact && !tags.isEmpty {
                            if source != nil { Text("·").accessibilityHidden(true) }
                            Text(tags.map { "#\($0.name)" }.joined(separator: " "))
                        }
                    }
                    .lineLimit(1)
                    .font(.system(size: 10))
                    .foregroundStyle(metadata)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
                .foregroundStyle(metadata)
            VStack(alignment: .trailing, spacing: 4) {
                Text(age)
                    .font(.system(size: style.compact ? 9 : 10))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin").accessibilityLabel("Pinned")
                    }
                    if isSelected {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .frame(height: 10)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(metadata)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: style.rowHeight)
        .background(isSelected ? style.selection : isHovered ? style.hover : .clear,
                    in: RoundedRectangle(cornerRadius: style.rowRadius))
        .contentShape(Rectangle())
    }

    private var symbol: String {
        if previewText.hasPrefix("http://") || previewText.hasPrefix("https://") || previewText.hasPrefix("www.") {
            return "link"
        }
        if previewText.hasPrefix("{") || previewText.hasPrefix("[") || previewText.hasPrefix("~/") {
            return "chevron.left.forwardslash.chevron.right"
        }
        return "doc.text"
    }

    private var age: String {
        let minutes = max(0, Int(Date().timeIntervalSince(item.timestamp) / 60))
        switch minutes {
        case 0: return "Just now"
        case 1..<60: return "\(minutes)m ago"
        case 60..<1440: return "\(minutes / 60)h ago"
        default: return "\(minutes / 1440)d ago"
        }
    }
}

extension ClipboardBrowserStyle {
    @ViewBuilder func rowSeparator(below index: Int, in items: [ClipboardItem], selectedID: UUID?) -> some View {
        if items.indices.contains(index + 1),
           items[index].id != selectedID, items[index + 1].id != selectedID,
           theme?.dividerStyle != DividerStyle.none {
            separator(theme?.dividerStyle == .thick ? 2 : 1)
                .padding(.leading, compact ? 40 : 48)
                .padding(.trailing, 8)
        }
    }
}
