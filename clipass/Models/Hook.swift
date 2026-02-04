import Foundation
import SwiftData

@Model
class Hook {
    var id: UUID
    var name: String
    var pattern: String
    var command: String
    var sourceAppFilter: String?
    var isEnabled: Bool
    var order: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pattern: String,
        command: String,
        sourceAppFilter: String? = nil,
        isEnabled: Bool = true,
        order: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.command = command
        self.sourceAppFilter = sourceAppFilter
        self.isEnabled = isEnabled
        self.order = order
        self.createdAt = createdAt
    }
}
