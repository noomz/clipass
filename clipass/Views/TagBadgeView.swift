import SwiftUI

/// Single tag badge: colored dot + tag name inside a Capsule background.
/// Uses TagInfo (plain struct) — zero SwiftData access during rendering.
struct TagBadgeView: View {
    let tag: TagInfo
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
/// Tags are pre-sorted by TagLookup — no sorting here.
struct TagBadgesRow: View {
    let tags: [TagInfo]
    let isSelected: Bool
    var overflowColor: Color = .secondary

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(Array(tags.prefix(3))) { tag in
                    TagBadgeView(tag: tag, isSelected: isSelected)
                }
                if tags.count > 3 {
                    Text("+\(tags.count - 3)")
                        .font(.caption2)
                        .foregroundColor(overflowColor)
                }
            }
        }
    }
}
