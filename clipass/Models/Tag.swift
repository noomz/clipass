import Foundation
import SwiftData
import SwiftUI

@Model
class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#3a8fd4"
    var createdAt: Date = Date()

    var items: [ClipboardItem] = []

    init(name: String, colorHex: String = "#3a8fd4") {
        self.name = name
        self.colorHex = colorHex
    }
}

extension Tag {
    /// Preset color palette — 8 saturated mid-range colors that work across all 5 themes.
    static let presetColors: [String] = [
        "#e05252",  // red
        "#e0873a",  // orange
        "#d4c140",  // yellow
        "#4db86a",  // green
        "#3a8fd4",  // blue
        "#6b52d4",  // purple
        "#cc52a8",  // pink
        "#888888",  // gray
    ]

    /// Returns a random preset color hex string.
    static func randomPresetColor() -> String {
        presetColors.randomElement() ?? "#3a8fd4"
    }
}
