import Foundation

extension ClipboardBrowserState.Item {
    @MainActor
    init(_ item: ClipboardItem, tagLookup: TagLookup) {
        id = item.id
        content = item.content
        timestamp = item.timestamp
        isPinned = item.isPinned
        tagNames = (tagLookup.tagsByItem[item.id] ?? []).map(\.name)
        isImage = item.isImage
    }
}
