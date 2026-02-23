import SwiftUI
import SwiftData
import AppKit

struct HistoryItemRow: View {
    let item: ClipboardItem
    let redactionPatterns: [RedactionPattern]
    let customActions: [ContextAction]
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    @AppStorage("previewMaxLength") private var previewMaxLength = 80
    @State private var isHovered = false

    private var formattedPreview: String {
        DisplayFormatter.format(item.content, maxLength: previewMaxLength, patterns: redactionPatterns)
    }

    private var contentTypes: Set<ContentType> {
        ContentAnalyzer.analyze(item.content)
    }

    private var applicableCustomActions: [ContextAction] {
        customActions.filter { ContextActionEngine.matches(action: $0, content: item.content) }
    }

    var body: some View {
        Button(action: copyToClipboard) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    Text(formattedPreview)
                        .lineLimit(1)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                HStack {
                    if let sourceApp = item.sourceApp {
                        Text(sourceApp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(relativeTimeString(from: item.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            // MARK: - Primary Actions
            Button("Copy") {
                copyToClipboard()
            }

            Button(item.isPinned ? "Unpin" : "Pin") {
                onTogglePin()
            }

            Divider()

            // MARK: - Text Transform Actions
            Menu("Copy As...") {
                Button("UPPERCASE") {
                    copyTransformed(item.content.uppercased())
                }
                Button("lowercase") {
                    copyTransformed(item.content.lowercased())
                }
                Button("Trimmed") {
                    copyTransformed(item.content.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                Divider()

                Button("Base64 Encoded") {
                    if let data = item.content.data(using: .utf8) {
                        copyTransformed(data.base64EncodedString())
                    }
                }
                Button("Base64 Decoded") {
                    if let data = Data(base64Encoded: item.content),
                       let decoded = String(data: data, encoding: .utf8) {
                        copyTransformed(decoded)
                    }
                }

                // URL encode/decode — shown when URL-like content
                if contentTypes.contains(.url) {
                    Divider()
                    Button("URL Encoded") {
                        if let encoded = item.content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                            copyTransformed(encoded)
                        }
                    }
                    Button("URL Decoded") {
                        if let decoded = item.content.removingPercentEncoding {
                            copyTransformed(decoded)
                        }
                    }
                }

                // Pretty JSON — shown when JSON detected
                if contentTypes.contains(.json) {
                    Divider()
                    Button("Formatted JSON") {
                        if let pretty = ContentAnalyzer.prettyJSON(item.content) {
                            copyTransformed(pretty)
                        }
                    }
                }
            }

            // MARK: - Content-Aware Actions
            if contentTypes.contains(.url) {
                Button("Open URL") {
                    openURL()
                }
            }

            if contentTypes.contains(.email) {
                Button("Send Email") {
                    sendEmail()
                }
            }

            if contentTypes.contains(.path) {
                Button("Open in Finder") {
                    openInFinder()
                }
            }

            // MARK: - Custom Actions
            // NOTE: Actions are placed directly in the context menu (not in a
            // submenu) because Button actions inside a Menu within .contextMenu
            // do not fire in MenuBarExtra(.window) panels — a known SwiftUI bug.
            if !applicableCustomActions.isEmpty {
                Divider()
                ForEach(applicableCustomActions, id: \.id) { contextAction in
                    Button(contextAction.name) {
                        ContextActionEngine.execute(action: contextAction, content: item.content)
                    }
                }
            }

            Divider()

            // MARK: - Destructive
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }

    // MARK: - Actions

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
    }

    private func copyTransformed(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func openURL() {
        let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        var urlString = trimmed
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func sendEmail() {
        let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: "mailto:\(trimmed)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInFinder() {
        let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = NSString(string: trimmed).expandingTildeInPath
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
