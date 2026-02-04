import Foundation
import SwiftData

class HookEngine {
    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func executeHooks(content: String, sourceApp: String?) {
        guard let context = modelContext else { return }

        // Fetch all enabled hooks sorted by order
        let descriptor = FetchDescriptor<Hook>(
            predicate: #Predicate { $0.isEnabled },
            sortBy: [SortDescriptor(\.order)]
        )

        guard let hooks = try? context.fetch(descriptor) else { return }

        for hook in hooks {
            // Filter by sourceAppFilter: nil or empty applies to all, otherwise must match
            if let filter = hook.sourceAppFilter, !filter.isEmpty {
                guard let app = sourceApp, app == filter else {
                    continue
                }
            }

            // Check pattern match: empty pattern matches all
            if !hook.pattern.isEmpty {
                do {
                    let regex = try Regex(hook.pattern)
                    guard content.contains(regex) else {
                        continue
                    }
                } catch {
                    // Invalid regex - skip this hook and log warning
                    print("[HookEngine] Invalid regex pattern '\(hook.pattern)' in hook '\(hook.name)': \(error)")
                    continue
                }
            }

            // Execute command asynchronously on background queue
            let command = hook.command
            let hookName = hook.name
            DispatchQueue.global(qos: .utility).async {
                self.runCommand(command, content: content, sourceApp: sourceApp, hookName: hookName)
            }
        }
    }

    private func runCommand(_ command: String, content: String, sourceApp: String?, hookName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        // Set environment variables
        var environment = ProcessInfo.processInfo.environment
        environment["CLIPASS_CONTENT"] = content
        environment["CLIPASS_SOURCE_APP"] = sourceApp ?? ""
        process.environment = environment

        do {
            try process.run()
            // Fire-and-forget: don't wait for completion
        } catch {
            print("[HookEngine] Failed to execute hook '\(hookName)': \(error)")
        }
    }
}
