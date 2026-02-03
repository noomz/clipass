import Foundation
import SwiftData

class TransformEngine {
    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
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
