import Foundation
import AppKit
import UserNotifications
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

    /// Execute a custom action's shell command with the clipboard content
    /// If replacesClipboard is true, captures stdout and puts it on the clipboard
    static func execute(action: ContextAction, content: String) {
        let command = action.command
        let actionName = action.name
        let replaces = action.replacesClipboard
        let notify = action.showNotification

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // Use login shell (-l) so the user's PATH and environment are loaded.
            // GUI apps inherit a minimal PATH; without -l, commands installed via
            // Homebrew or other tools won't be found.
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
                showErrorNotification(actionName: actionName, message: "Failed to launch: \(error.localizedDescription)")
                return
            }

            // Read stdout and stderr concurrently to avoid pipe buffer deadlock.
            // If we called waitUntilExit() first, a process that fills the pipe
            // buffer (~64KB) would block forever waiting for us to read.
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
            let stderrString = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if exitCode != 0 {
                logger.error("Action '\(actionName)' exited with code \(exitCode). stderr: \(stderrString)")
                let errorMessage = stderrString.isEmpty
                    ? "Exited with code \(exitCode)"
                    : stderrString
                showErrorNotification(actionName: actionName, message: errorMessage)
                return
            }

            let stdoutString = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""

            if replaces && !stdoutString.isEmpty {
                DispatchQueue.main.async {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(stdoutString, forType: .string)
                }
                if notify {
                    let preview = stdoutString.count > 80
                        ? String(stdoutString.prefix(80)) + "..."
                        : stdoutString
                    showSuccessNotification(actionName: actionName, message: "Clipboard updated: \(preview)")
                }
            } else if notify {
                if stdoutString.isEmpty {
                    showSuccessNotification(actionName: actionName, message: "Completed successfully")
                } else {
                    let preview = stdoutString.count > 80
                        ? String(stdoutString.prefix(80)) + "..."
                        : stdoutString
                    showSuccessNotification(actionName: actionName, message: preview)
                }
            }
        }
    }

    /// Post a macOS notification when an action fails
    private static func showErrorNotification(actionName: String, message: String) {
        showNotification(title: "Action Failed: \(actionName)", body: message, sound: true)
    }

    /// Post a macOS notification when an action succeeds
    private static func showSuccessNotification(actionName: String, message: String) {
        showNotification(title: actionName, body: message, sound: false)
    }

    /// Post a macOS notification
    private static func showNotification(title: String, body: String, sound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logger.error("Failed to deliver notification: \(error)")
            }
        }
    }
}
