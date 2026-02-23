import Foundation
import SwiftData

@Model
class ContextAction {
    var id: UUID = UUID()
    var name: String = ""
    var command: String = ""
    var contentFilter: String = ""  // regex pattern; empty = always show
    var replacesClipboard: Bool = false  // if true, stdout replaces clipboard
    var showNotification: Bool = true  // show macOS notification on success
    var isEnabled: Bool = true
    var order: Int = 0
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        contentFilter: String = "",
        replacesClipboard: Bool = false,
        showNotification: Bool = true,
        isEnabled: Bool = true,
        order: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.contentFilter = contentFilter
        self.replacesClipboard = replacesClipboard
        self.showNotification = showNotification
        self.isEnabled = isEnabled
        self.order = order
        self.createdAt = createdAt
    }
}
