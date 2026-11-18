import XCTest
@testable import clipass

final class DisplayFormatterTests: XCTestCase {
    func testFullPreviewPreservesLayoutWhileRowsRedactBeforeTruncating() {
        let enabled = RedactionPattern(name: "Fixture", pattern: #"token-\d+\n\s*continued"#,
                                       category: RedactionPattern.categoryCustom)
        let disabled = RedactionPattern(name: "Disabled", pattern: "visible",
                                        category: RedactionPattern.categoryCustom, isEnabled: false)
        let original = "Title\n\ttoken-123456\n  continued\nvisible\nTail"
        let patterns = [enabled, disabled]

        XCTAssertEqual(DisplayFormatter.redact(original, patterns: patterns), "Title\n\t***\nvisible\nTail")
        XCTAssertEqual(DisplayFormatter.format(original, maxLength: 14, patterns: patterns), "Title  ***...")
    }
}
