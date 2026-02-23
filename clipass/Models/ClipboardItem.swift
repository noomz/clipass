import Foundation
import SwiftData

@Model
class ClipboardItem {
    var id: UUID = UUID()
    var content: String = ""
    var sourceApp: String?
    var timestamp: Date = Date()
    var isPinned: Bool = false

    init(id: UUID = UUID(), content: String, sourceApp: String? = nil, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.sourceApp = sourceApp
        self.timestamp = timestamp
        self.isPinned = isPinned
    }
}
