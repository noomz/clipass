import Foundation
import SwiftData

class TransformEngine {
    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Default Rules

    /// Creates default rules if no rules exist
    static func createDefaultRulesIfNeeded(context: ModelContext) {
        // Check if any rules exist
        let descriptor = FetchDescriptor<TransformRule>()
        guard let existingRules = try? context.fetch(descriptor), existingRules.isEmpty else {
            return
        }

        createDefaultRules(context: context)
    }

    /// Deletes all rules and recreates defaults
    static func resetToDefaultRules(context: ModelContext) {
        // Delete all existing rules
        let descriptor = FetchDescriptor<TransformRule>()
        if let existingRules = try? context.fetch(descriptor) {
            for rule in existingRules {
                context.delete(rule)
            }
        }

        createDefaultRules(context: context)
    }

    private static func createDefaultRules(context: ModelContext) {
        let defaultRules = [
            TransformRule(
                name: "Strip Terminal trailing whitespace",
                pattern: "\\s+$",
                replacement: "",
                sourceAppFilter: "com.apple.Terminal",
                isEnabled: true,
                order: 10
            ),
            TransformRule(
                name: "Strip trailing whitespace",
                pattern: "\\s+$",
                replacement: "",
                sourceAppFilter: nil,
                isEnabled: true,
                order: 100
            ),
            TransformRule(
                name: "Normalize line endings",
                pattern: "\\r\\n",
                replacement: "\n",
                sourceAppFilter: nil,
                isEnabled: true,
                order: 200
            )
        ]

        for rule in defaultRules {
            context.insert(rule)
        }
    }

    func transform(_ content: String, sourceApp: String?) -> String {
        guard let context = modelContext else { return content }

        // Fetch all enabled rules sorted by order
        let descriptor = FetchDescriptor<TransformRule>(
            predicate: #Predicate { $0.isEnabled },
            sortBy: [SortDescriptor(\.order)]
        )

        guard let rules = try? context.fetch(descriptor) else { return content }

        var result = content

        for rule in rules {
            // Filter by sourceAppFilter: nil applies to all, otherwise must match
            if let filter = rule.sourceAppFilter, !filter.isEmpty {
                guard let app = sourceApp, app == filter else {
                    continue
                }
            }

            // Try to compile and apply the regex
            do {
                let regex = try Regex(rule.pattern)
                result = result.replacing(regex, with: rule.replacement)
            } catch {
                // Invalid regex - skip this rule and log warning
                print("[TransformEngine] Invalid regex pattern '\(rule.pattern)' in rule '\(rule.name)': \(error)")
            }
        }

        return result
    }
}
