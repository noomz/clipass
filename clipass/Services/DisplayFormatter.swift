import Foundation
import SwiftData

/// DisplayFormatter handles display-only formatting: stripping invisible characters,
/// truncating at word boundaries, and applying redaction with partial masking.
struct DisplayFormatter {
    // MARK: - Pattern Cache

    private static var patternCache: [String: Regex<AnyRegexOutput>] = [:]
    private static let cacheLock = NSLock()

    /// Invalidate the pattern cache (call when user edits patterns)
    static func invalidateCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        patternCache.removeAll()
    }

    private static func compiledPattern(for pattern: String) -> Regex<AnyRegexOutput>? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = patternCache[pattern] {
            return cached
        }

        guard let regex = try? Regex(pattern) else {
            return nil
        }

        patternCache[pattern] = regex
        return regex
    }

    // MARK: - Main Format Pipeline

    /// Format content for display: stripInvisibles -> redact -> truncate
    static func format(_ content: String, maxLength: Int, patterns: [RedactionPattern]) -> String {
        var result = stripInvisibles(content)
        result = redact(result, patterns: patterns)
        result = truncate(result, maxLength: maxLength)
        return result
    }

    // MARK: - Strip Invisibles

    /// Remove all \n, \r, \t characters, keep spaces as-is
    static func stripInvisibles(_ content: String) -> String {
        var result = content
        result = result.replacingOccurrences(of: "\n", with: " ")
        result = result.replacingOccurrences(of: "\r", with: " ")
        result = result.replacingOccurrences(of: "\t", with: " ")
        return result
    }

    // MARK: - Truncate

    /// Truncate at word boundary with ellipsis
    static func truncate(_ content: String, maxLength: Int) -> String {
        guard content.count > maxLength else { return content }

        let truncated = String(content.prefix(maxLength))

        // Find last space within maxLength and break at word boundary
        if let lastSpaceIndex = truncated.lastIndex(of: " "),
           lastSpaceIndex > truncated.startIndex {
            return String(truncated[..<lastSpaceIndex]) + "..."
        }

        // No space found (single long word), truncate at maxLength
        return truncated + "..."
    }

    // MARK: - Redact

    /// Apply enabled redaction patterns with partial masking
    static func redact(_ content: String, patterns: [RedactionPattern]) -> String {
        var result = content

        for pattern in patterns where pattern.isEnabled {
            guard let regex = compiledPattern(for: pattern.pattern) else { continue }

            let matches = result.matches(of: regex)
            // Process matches in reverse to preserve indices
            for match in matches.reversed() {
                let matchedString = String(result[match.range])
                let masked = maskMatch(matchedString, category: pattern.category)
                result.replaceSubrange(match.range, with: masked)
            }
        }

        return result
    }

    // MARK: - Masking Functions

    private static func maskMatch(_ match: String, category: String) -> String {
        switch category {
        case RedactionPattern.categoryPII:
            // Check if it looks like an email
            if match.contains("@") {
                return maskEmail(match)
            }
            // Default to generic for phone numbers
            return maskGeneric(match)

        case RedactionPattern.categoryCredentials:
            return maskAPIKey(match)

        case RedactionPattern.categoryFinancial:
            return maskCreditCard(match)

        default:
            return maskGeneric(match)
        }
    }

    /// Mask email: john@example.com -> j***@e***.com
    private static func maskEmail(_ match: String) -> String {
        let parts = match.split(separator: "@")
        guard parts.count == 2 else { return maskGeneric(match) }

        let localPart = String(parts[0])
        let domainPart = String(parts[1])

        // Get first char of local part
        let maskedLocal = localPart.isEmpty ? "***" : String(localPart.prefix(1)) + "***"

        // Split domain by last dot to get domain and TLD
        if let lastDot = domainPart.lastIndex(of: ".") {
            let domain = String(domainPart[..<lastDot])
            let tld = String(domainPart[domainPart.index(after: lastDot)...])
            let maskedDomain = domain.isEmpty ? "***" : String(domain.prefix(1)) + "***"
            return "\(maskedLocal)@\(maskedDomain).\(tld)"
        }

        // No TLD found, just mask the whole domain
        let maskedDomain = domainPart.isEmpty ? "***" : String(domainPart.prefix(1)) + "***"
        return "\(maskedLocal)@\(maskedDomain)"
    }

    /// Mask API key: sk-xxxx-REDACTED -> sk-***...***
    private static func maskAPIKey(_ match: String) -> String {
        // Find first delimiter (-, _)
        var prefix = ""
        for (index, char) in match.enumerated() {
            if char == "-" || char == "_" {
                prefix = String(match.prefix(index + 1))
                break
            }
            if index >= 3 {
                // Keep first 3-4 chars as prefix
                prefix = String(match.prefix(4))
                break
            }
        }

        if prefix.isEmpty {
            prefix = String(match.prefix(min(4, match.count)))
        }

        return prefix + "***...***"
    }

    /// Mask credit card: 4111111111111111 -> ****-****-****-1111
    private static func maskCreditCard(_ match: String) -> String {
        // Remove any non-digits
        let digitsOnly = match.filter { $0.isNumber }
        guard digitsOnly.count >= 4 else { return maskGeneric(match) }

        let lastFour = String(digitsOnly.suffix(4))
        return "****-****-****-\(lastFour)"
    }

    /// Generic mask: replace with ***
    private static func maskGeneric(_ match: String) -> String {
        return "***"
    }

    // MARK: - Default Patterns

    /// Returns the built-in default patterns
    static func defaultPatterns() -> [RedactionPattern] {
        return [
            // Credentials (enabled by default)
            RedactionPattern(
                name: "OpenAI API Key",
                pattern: #"sk-(?:proj|svcacct|admin)-[A-Za-z0-9_-]{20,}"#,
                category: RedactionPattern.categoryCredentials,
                isEnabled: true,
                isBuiltIn: true
            ),
            RedactionPattern(
                name: "GitHub PAT",
                pattern: #"ghp_[0-9a-zA-Z]{36}"#,
                category: RedactionPattern.categoryCredentials,
                isEnabled: true,
                isBuiltIn: true
            ),
            RedactionPattern(
                name: "AWS Access Key",
                pattern: #"(?:A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)[A-Z2-7]{16}"#,
                category: RedactionPattern.categoryCredentials,
                isEnabled: true,
                isBuiltIn: true
            ),
            RedactionPattern(
                name: "Stripe Key",
                pattern: #"(?:sk|rk)_(?:test|live|prod)_[a-zA-Z0-9]{10,99}"#,
                category: RedactionPattern.categoryCredentials,
                isEnabled: true,
                isBuiltIn: true
            ),

            // Financial (enabled by default)
            RedactionPattern(
                name: "Credit Card",
                pattern: #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b"#,
                category: RedactionPattern.categoryFinancial,
                isEnabled: true,
                isBuiltIn: true
            ),

            // PII (disabled by default)
            RedactionPattern(
                name: "Email",
                pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
                category: RedactionPattern.categoryPII,
                isEnabled: false,
                isBuiltIn: true
            ),
            RedactionPattern(
                name: "Phone",
                pattern: #"(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#,
                category: RedactionPattern.categoryPII,
                isEnabled: false,
                isBuiltIn: true
            )
        ]
    }

    // MARK: - Database Initialization

    /// Create default patterns if none exist (called on app startup)
    @MainActor
    static func createDefaultPatternsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<RedactionPattern>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else { return }

        for pattern in defaultPatterns() {
            context.insert(pattern)
        }

        try? context.save()
    }
}
