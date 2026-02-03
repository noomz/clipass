import Foundation
import SwiftData

@Model
class ClipboardItem {
    var id: UUID
    var content: String
    var sourceApp: String?
    var timestamp: Date

    init(id: UUID = UUID(), content: String, sourceApp: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.sourceApp = sourceApp
        self.timestamp = timestamp
    }
}
