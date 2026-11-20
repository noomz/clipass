import Foundation
import SwiftData

@Model
class ClipboardItem {
    var id: UUID = UUID()
    var content: String = ""
    var sourceApp: String?
    var timestamp: Date = Date()
    var isPinned: Bool = false
    // Image items keep a searchable label such as "Image 1440×900" in `content`.
    @Attribute(.externalStorage) var imageData: Data?
    var thumbnailData: Data?
    var imageHash: String?

    @Relationship(inverse: \Tag.items)
    var tags: [Tag] = []

    init(id: UUID = UUID(), content: String, sourceApp: String? = nil, timestamp: Date = Date(), isPinned: Bool = false,
         imageData: Data? = nil, thumbnailData: Data? = nil, imageHash: String? = nil) {
        self.id = id
        self.content = content
        self.sourceApp = sourceApp
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.imageHash = imageHash
    }

    // Reads the hash, not imageData: snapshots evaluate this every render, and imageData lives in an external file.
    var isImage: Bool { imageHash != nil }

    var payload: ClipboardPayload {
        imageData.map(ClipboardPayload.image) ?? .text(content)
    }
}
