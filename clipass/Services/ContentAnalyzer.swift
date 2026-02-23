import Foundation

enum ContentType: String, CaseIterable {
    case url
    case email
    case json
    case number
    case path
    case hexColor
    case text
}

struct ContentAnalyzer {
    /// Analyze content and return all detected types
    static func analyze(_ content: String) -> Set<ContentType> {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [.text] }

        var types: Set<ContentType> = [.text] // text is always present

        if isURL(trimmed) { types.insert(.url) }
        if isEmail(trimmed) { types.insert(.email) }
        if isJSON(trimmed) { types.insert(.json) }
        if isNumber(trimmed) { types.insert(.number) }
        if isPath(trimmed) { types.insert(.path) }
        if isHexColor(trimmed) { types.insert(.hexColor) }

        return types
    }

    // MARK: - Detectors

    private static func isURL(_ content: String) -> Bool {
        // Check for common URL patterns
        let urlPattern = #"^(https?://|www\.)\S+"#
        if content.range(of: urlPattern, options: .regularExpression) != nil {
            return true
        }
        // Also try URL parsing for less obvious URLs
        if let url = URL(string: content), let scheme = url.scheme,
           ["http", "https", "ftp"].contains(scheme) {
            return true
        }
        return false
    }

    private static func isEmail(_ content: String) -> Bool {
        let emailPattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return content.range(of: emailPattern, options: .regularExpression) != nil
    }

    private static func isJSON(_ content: String) -> Bool {
        guard let data = content.data(using: .utf8) else { return false }
        // Must start with { or [ to be JSON
        let first = content.first
        guard first == "{" || first == "[" else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func isNumber(_ content: String) -> Bool {
        let numberPattern = #"^-?\d+(\.\d+)?$"#
        return content.range(of: numberPattern, options: .regularExpression) != nil
    }

    private static func isPath(_ content: String) -> Bool {
        return content.hasPrefix("/") || content.hasPrefix("~/")
    }

    private static func isHexColor(_ content: String) -> Bool {
        let hexPattern = #"^#[0-9a-fA-F]{3,8}$"#
        return content.range(of: hexPattern, options: .regularExpression) != nil
    }

    // MARK: - Utilities

    /// Pretty-print JSON content, returns nil if not valid JSON
    static func prettyJSON(_ content: String) -> String? {
        guard let data = content.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return result
    }
}
