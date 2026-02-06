import Foundation
import SwiftData

@Model
class IgnoredPattern {
    var id: UUID
    var name: String
    var pattern: String
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pattern: String,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}
