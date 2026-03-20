import SwiftUI

/// Single tag badge: colored dot + tag name inside a Capsule background.
struct TagBadgeView: View {
    let tag: Tag
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 6, height: 6)
            Text(tag.name)
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.85) : Color(hex: tag.colorHex))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(hex: tag.colorHex).opacity(isSelected ? 0.3 : 0.15))
        )
    }
}

/// Horizontal strip of up to 3 tag badges with optional "+N" overflow indicator.
/// Sorts tags alphabetically. Renders EmptyView when tags array is empty.
struct TagBadgesRow: View {
    let tags: [Tag]
    let isSelected: Bool
    var overflowColor: Color = .secondary

    private var sortedTags: [Tag] {
        tags.sorted { $0.name < $1.name }
    }

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(Array(sortedTags.prefix(3))) { tag in
                    TagBadgeView(tag: tag, isSelected: isSelected)
                }
                if sortedTags.count > 3 {
                    Text("+\(sortedTags.count - 3)")
                        .font(.caption2)
                        .foregroundColor(overflowColor)
                }
            }
        }
    }
}
