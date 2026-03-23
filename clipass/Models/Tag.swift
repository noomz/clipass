import Foundation
import SwiftData
import SwiftUI

@Model
class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#3a8fd4"
    var createdAt: Date = Date()

    var items: [ClipboardItem] = []

    init(name: String, colorHex: String = "#3a8fd4") {
        self.name = name
        self.colorHex = colorHex
    }
}

// MARK: - Display-only tag data (no SwiftData, no DB faults)

/// Lightweight tag snapshot for view rendering. Zero relationship access.
struct TagInfo: Identifiable, Hashable {
    let id: UUID
    let name: String
    let colorHex: String
}

/// Pre-computed tag lookup — built by faulting from the Tag side (few queries)
/// instead of the Item side (hundreds of queries). O(1) lookup per item.
struct TagLookup {
    let allTags: [TagInfo]
    let tagsByItem: [UUID: [TagInfo]]       // ClipboardItem.id → sorted tags
    let itemIDsByTag: [String: Set<UUID>]   // lowercase tag name → item IDs

    static let empty = TagLookup(allTags: [], tagsByItem: [:], itemIDsByTag: [:])

    /// Build lookup by fetching all Tags (small set) and traversing tag→items.
    /// This faults N tag relationships (typically <20) instead of M item relationships (hundreds).
    @MainActor
    static func build(from context: ModelContext) -> TagLookup {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        guard let tags = try? context.fetch(descriptor) else { return .empty }

        let allTagInfos = tags.map { TagInfo(id: $0.id, name: $0.name, colorHex: $0.colorHex) }

        var byItem: [UUID: [TagInfo]] = [:]
        var byTag: [String: Set<UUID>] = [:]

        for tag in tags {
            let info = TagInfo(id: tag.id, name: tag.name, colorHex: tag.colorHex)
            let nameLower = tag.name.lowercased()
            for item in tag.items {
                byItem[item.id, default: []].append(info)
                byTag[nameLower, default: []].insert(item.id)
            }
        }

        // Sort tags per item alphabetically
        for (key, value) in byItem {
            byItem[key] = value.sorted { $0.name < $1.name }
        }

        return TagLookup(allTags: allTagInfos, tagsByItem: byItem, itemIDsByTag: byTag)
    }
}

extension Tag {
    /// Preset color palette — 8 saturated mid-range colors that work across all 5 themes.
    static let presetColors: [String] = [
        "#e05252",  // red
        "#e0873a",  // orange
        "#d4c140",  // yellow
        "#4db86a",  // green
        "#3a8fd4",  // blue
        "#6b52d4",  // purple
        "#cc52a8",  // pink
        "#888888",  // gray
    ]

    /// Returns a random preset color hex string.
    static func randomPresetColor() -> String {
        presetColors.randomElement() ?? "#3a8fd4"
    }
}
