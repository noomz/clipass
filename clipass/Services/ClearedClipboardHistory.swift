import Foundation
import SwiftData

struct ClearedClipboardHistory {
    private struct Entry {
        let id: UUID
        let content: String
        let sourceApp: String?
        let timestamp: Date
        let tagIDs: [UUID]

        init(_ item: ClipboardItem) {
            id = item.id
            content = item.content
            sourceApp = item.sourceApp
            timestamp = item.timestamp
            tagIDs = item.tags.map(\.id)
        }
    }

    private let entries: [Entry]
    var count: Int { entries.count }

    @MainActor
    static func clear(in context: ModelContext) throws -> Self {
        let items = try context.fetch(FetchDescriptor<ClipboardItem>(predicate: #Predicate { !$0.isPinned }))
        let history = Self(entries: items.map(Entry.init))
        try saveChanges(in: context) {
            for item in items { context.delete(item) }
        }
        return history
    }

    @MainActor
    func restore(in context: ModelContext) throws {
        let tags = try context.fetch(FetchDescriptor<Tag>())
        let tagsByID = Dictionary(tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existing = Set(try context.fetch(FetchDescriptor<ClipboardItem>()).map(\.id))
        try Self.saveChanges(in: context) {
            for entry in entries where !existing.contains(entry.id) {
                let item = ClipboardItem(id: entry.id, content: entry.content, sourceApp: entry.sourceApp,
                                         timestamp: entry.timestamp)
                context.insert(item)
                item.tags = entry.tagIDs.compactMap { tagsByID[$0] }
            }
        }
    }

    @MainActor
    private static func saveChanges(in context: ModelContext, _ change: () -> Void) throws {
        if context.hasChanges { try context.save() }
        change()
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
