import Foundation
import SwiftData

@Model
class TransformRule {
    var id: UUID
    var name: String
    var pattern: String
    var replacement: String
    var sourceAppFilter: String?
    var isEnabled: Bool
    var order: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pattern: String,
        replacement: String,
        sourceAppFilter: String? = nil,
        isEnabled: Bool = true,
        order: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.replacement = replacement
        self.sourceAppFilter = sourceAppFilter
        self.isEnabled = isEnabled
        self.order = order
        self.createdAt = createdAt
    }
}
