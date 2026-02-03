import Foundation

struct ClipboardItem: Identifiable {
    let id: UUID
    let content: String
    let sourceApp: String?
    let timestamp: Date

    init(id: UUID = UUID(), content: String, sourceApp: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.sourceApp = sourceApp
        self.timestamp = timestamp
    }
}
