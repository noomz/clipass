import Foundation
import SwiftData

@Model
class IgnoredApp {
    var id: UUID = UUID()
    var bundleId: String = ""
    var name: String = ""
    var isEnabled: Bool = true
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        bundleId: String,
        name: String,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.bundleId = bundleId
        self.name = name
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}
