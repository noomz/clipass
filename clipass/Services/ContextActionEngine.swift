import Foundation
import AppKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "clipass", category: "ContextActionEngine")

class ContextActionEngine {
    /// Check if a custom action's filter matches the given content
    static func matches(action: ContextAction, content: String) -> Bool {
        guard !action.contentFilter.isEmpty else { return true } // empty filter = always show
        guard action.isEnabled else { return false }
        do {
            let regex = try Regex(action.contentFilter)
            return content.contains(regex)
        } catch {
            logger.warning("Invalid regex '\(action.contentFilter)' in action '\(action.name)': \(error)")
            return false
        }
    }

    /// Execute a custom action's shell command with the clipboard content.
    /// Must be called from the main thread (SwiftData objects are not thread-safe).
    static func execute(action: ContextAction, content: String) {
        // Capture all SwiftData values on the calling thread before dispatching
        let command = action.command
        let actionName = action.name
        let replaces = action.replacesClipboard
        let notify = action.showNotification

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]

            var environment = ProcessInfo.processInfo.environment
            environment["CLIPASS_CONTENT"] = content
            process.environment = environment

            // Provide content via stdin so commands can read from it directly
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            if let inputData = content.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(inputData)
            }
            stdinPipe.fileHandleForWriting.closeFile()

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                logger.error("Failed to launch action '\(actionName)': \(error)")
                showAlert(title: "Action Failed: \(actionName)", message: "Failed to launch: \(error.localizedDescription)", copyText: nil, isError: true)
                return
            }

            // Read stdout and stderr concurrently to avoid pipe buffer deadlock
            var stdoutData = Data()
            var stderrData = Data()

            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.enter()
            DispatchQueue.global().async {
                stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            process.waitUntilExit()
            group.wait()

            let exitCode = process.terminationStatus
            let stdoutString = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
            let stderrString = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if exitCode != 0 {
                logger.error("Action '\(actionName)' exited with code \(exitCode). stderr: \(stderrString)")
                let errorMessage = stderrString.isEmpty
                    ? "Exited with code \(exitCode)"
                    : stderrString
                showAlert(title: "Action Failed: \(actionName)", message: errorMessage, copyText: nil, isError: true)
                return
            }

            // Success
            if replaces && !stdoutString.isEmpty {
                DispatchQueue.main.async {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(stdoutString, forType: .string)
                }
                if notify {
                    let preview = truncate(stdoutString, to: 200)
                    showAlert(title: actionName, message: "Clipboard updated:\n\(preview)", copyText: stdoutString, isError: false)
                }
            } else if notify {
                let preview = stdoutString.isEmpty
                    ? "Completed successfully"
                    : truncate(stdoutString, to: 200)
                showAlert(title: actionName, message: preview, copyText: stdoutString, isError: false)
            }

            logger.info("Action '\(actionName)' completed. exit=0 stdout=\(stdoutString.prefix(200)) stderr=\(stderrString.prefix(200))")
        }
    }

    // MARK: - Private

    private static func truncate(_ text: String, to maxLength: Int) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) + "..." : text
    }

    private static func showAlert(title: String, message: String, copyText: String?, isError: Bool) {
        DispatchQueue.main.async {
            // Bring app to front so the alert is visible
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = isError ? .critical : .informational
            alert.addButton(withTitle: "OK")
            if let fullText = copyText, !fullText.isEmpty {
                alert.addButton(withTitle: "Copy Output")
                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fullText, forType: .string)
                }
            } else {
                alert.runModal()
            }
        }
    }
}
