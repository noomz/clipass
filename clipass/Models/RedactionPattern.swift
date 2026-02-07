import Foundation
import SwiftData

@Model
class RedactionPattern {
    // Category constants
    static let categoryCredentials = "Credentials"
    static let categoryPII = "PII"
    static let categoryFinancial = "Financial"
    static let categoryCustom = "Custom"

    var id: UUID
    var name: String
    var pattern: String
    var category: String
    var isEnabled: Bool
    var isBuiltIn: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pattern: String,
        category: String,
        isEnabled: Bool = true,
        isBuiltIn: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.category = category
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }
}
