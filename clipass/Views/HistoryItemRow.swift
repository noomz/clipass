import SwiftUI
import SwiftData
import AppKit

struct HistoryItemRow: View {
    let item: ClipboardItem
    let previewText: String            // Pre-computed by parent
    let tagInfos: [TagInfo]            // From TagLookup — no DB access
    let allTags: [Tag]                 // For context menu
    let redactionPatterns: [RedactionPattern]
    let customActions: [ContextAction]
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    var onTagChanged: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    @State private var isHovered = false

    var body: some View {
        Button(action: copyToClipboard) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    Text(previewText)
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
                    TagBadgesRow(tags: tagInfos, isSelected: false, overflowColor: .secondary)
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
        .overlay {
            // Invisible right-click target — builds NSMenu on demand, not during body eval
            RightClickReceiver {
                buildContextMenu()
            }
        }
    }

    // MARK: - NSMenu (built on-demand, not during SwiftUI body evaluation)

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Primary actions
        menu.addItem(NSMenuItem(title: "Copy", action: nil, keyEquivalent: "").configured {
            $0.representedObject = { copyToClipboard() } as () -> Void
            $0.target = ContextMenuActionTarget.shared
            $0.action = #selector(ContextMenuActionTarget.performAction(_:))
        })

        menu.addItem(NSMenuItem(title: item.isPinned ? "Unpin" : "Pin", action: nil, keyEquivalent: "").configured {
            $0.representedObject = { [onTogglePin] in onTogglePin() } as () -> Void
            $0.target = ContextMenuActionTarget.shared
            $0.action = #selector(ContextMenuActionTarget.performAction(_:))
        })

        menu.addItem(.separator())

        // Tag assignment (flat buttons — MenuBarExtra submenu bug)
        for tag in allTags {
            let isTagged = tagInfos.contains { $0.id == tag.id }
            let title = isTagged ? "\u{2713} \(tag.name)" : "    \(tag.name)"
            menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: "").configured {
                $0.representedObject = { [weak tag, weak item] in
                    guard let tag, let item else { return }
                    toggleTag(tag, on: item)
                } as () -> Void
                $0.target = ContextMenuActionTarget.shared
                $0.action = #selector(ContextMenuActionTarget.performAction(_:))
            })
        }
        menu.addItem(NSMenuItem(title: "+ New Tag...", action: nil, keyEquivalent: "").configured {
            $0.representedObject = { presentNewTagAlert() } as () -> Void
            $0.target = ContextMenuActionTarget.shared
            $0.action = #selector(ContextMenuActionTarget.performAction(_:))
        })

        menu.addItem(.separator())

        // Copy As... submenu
        let copyAsSubmenu = NSMenu()
        let copyAsItem = NSMenuItem(title: "Copy As...", action: nil, keyEquivalent: "")
        copyAsItem.submenu = copyAsSubmenu

        addAction(to: copyAsSubmenu, title: "UPPERCASE") { copyTransformed(item.content.uppercased()) }
        addAction(to: copyAsSubmenu, title: "lowercase") { copyTransformed(item.content.lowercased()) }
        addAction(to: copyAsSubmenu, title: "Trimmed") { copyTransformed(item.content.trimmingCharacters(in: .whitespacesAndNewlines)) }
        copyAsSubmenu.addItem(.separator())
        addAction(to: copyAsSubmenu, title: "Base64 Encoded") {
            if let data = item.content.data(using: .utf8) { copyTransformed(data.base64EncodedString()) }
        }
        addAction(to: copyAsSubmenu, title: "Base64 Decoded") {
            if let data = Data(base64Encoded: item.content), let decoded = String(data: data, encoding: .utf8) { copyTransformed(decoded) }
        }

        // Content-aware transforms — only computed here, on right-click
        let contentTypes = ContentAnalyzer.analyze(item.content)

        if contentTypes.contains(.url) {
            copyAsSubmenu.addItem(.separator())
            addAction(to: copyAsSubmenu, title: "URL Encoded") {
                if let encoded = item.content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) { copyTransformed(encoded) }
            }
            addAction(to: copyAsSubmenu, title: "URL Decoded") {
                if let decoded = item.content.removingPercentEncoding { copyTransformed(decoded) }
            }
        }

        if contentTypes.contains(.json) {
            copyAsSubmenu.addItem(.separator())
            addAction(to: copyAsSubmenu, title: "Formatted JSON") {
                if let pretty = ContentAnalyzer.prettyJSON(item.content) { copyTransformed(pretty) }
            }
        }

        menu.addItem(copyAsItem)

        // Content-aware actions
        if contentTypes.contains(.url) {
            addAction(to: menu, title: "Open URL") { openURL() }
        }
        if contentTypes.contains(.email) {
            addAction(to: menu, title: "Send Email") { sendEmail() }
        }
        if contentTypes.contains(.path) {
            addAction(to: menu, title: "Open in Finder") { openInFinder() }
        }

        // Custom actions — filtered on demand
        let applicable = customActions.filter { ContextActionEngine.matches(action: $0, content: item.content) }
        if !applicable.isEmpty {
            menu.addItem(.separator())
            for contextAction in applicable {
                addAction(to: menu, title: contextAction.name) {
                    ContextActionEngine.execute(action: contextAction, content: item.content)
                }
            }
        }

        menu.addItem(.separator())

        // Delete
        let deleteItem = NSMenuItem(title: "Delete", action: nil, keyEquivalent: "")
        deleteItem.representedObject = { [onDelete] in onDelete() } as () -> Void
        deleteItem.target = ContextMenuActionTarget.shared
        deleteItem.action = #selector(ContextMenuActionTarget.performAction(_:))
        // Red text for destructive
        deleteItem.attributedTitle = NSAttributedString(
            string: "Delete",
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        menu.addItem(deleteItem)

        return menu
    }

    private func addAction(to menu: NSMenu, title: String, action: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.representedObject = action as () -> Void
        item.target = ContextMenuActionTarget.shared
        item.action = #selector(ContextMenuActionTarget.performAction(_:))
        menu.addItem(item)
    }

    // MARK: - Tag Actions

    private func toggleTag(_ tag: Tag, on item: ClipboardItem) {
        if let index = item.tags.firstIndex(where: { $0.id == tag.id }) {
            item.tags.remove(at: index)
        } else {
            item.tags.append(tag)
        }
        try? modelContext.save()
        onTagChanged?()
    }

    private func presentNewTagAlert() {
        let alert = NSAlert()
        alert.messageText = "New Tag"
        alert.informativeText = "Enter a name for the new tag."
        alert.addButton(withTitle: "Create Tag")
        alert.addButton(withTitle: "Don't Create")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "Tag name"
        alert.accessoryView = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                let newTag = Tag(name: name, colorHex: Tag.randomPresetColor())
                modelContext.insert(newTag)
                item.tags.append(newTag)
                try? modelContext.save()
                onTagChanged?()
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

// MARK: - NSMenuItem builder helper

private extension NSMenuItem {
    func configured(_ configure: (NSMenuItem) -> Void) -> NSMenuItem {
        configure(self)
        return self
    }
}

// MARK: - Singleton target for NSMenu action dispatch

/// Bridges NSMenuItem actions to Swift closures stored in `representedObject`.
/// Singleton so NSMenu can always find a valid target.
final class ContextMenuActionTarget: NSObject {
    static let shared = ContextMenuActionTarget()
    private override init() { super.init() }

    @objc func performAction(_ sender: NSMenuItem) {
        if let action = sender.representedObject as? () -> Void {
            action()
        }
    }
}

// MARK: - Right-click interceptor (NSView-backed, zero SwiftUI overhead)

/// Transparent overlay that intercepts right-click events and shows an NSMenu.
/// The menu is built lazily via the `menuBuilder` closure — nothing is constructed
/// until the user actually right-clicks.
struct RightClickReceiver: NSViewRepresentable {
    let menuBuilder: () -> NSMenu

    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.menuBuilder = menuBuilder
        return view
    }

    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.menuBuilder = menuBuilder
    }

    final class RightClickNSView: NSView {
        var menuBuilder: (() -> NSMenu)?

        override func rightMouseDown(with event: NSEvent) {
            guard let menu = menuBuilder?() else { return }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        // Pass through left-clicks so the Button action still works
        override func hitTest(_ point: NSPoint) -> NSView? {
            // Only claim right-clicks
            guard NSApp.currentEvent?.type == .rightMouseDown else { return nil }
            return super.hitTest(point)
        }
    }
}
