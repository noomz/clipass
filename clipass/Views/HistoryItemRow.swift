import SwiftUI
import SwiftData
import AppKit

struct HistoryItemRow: View {
    let item: ClipboardItem
    let previewText: String            // Pre-computed by parent
    let tagInfos: [TagInfo]            // From TagLookup — no DB access
    let allTags: [Tag]                 // For context menu
    let customActions: [ContextAction]
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    var onTagChanged: (() -> Void)? = nil
    var isSelected = false
    var onSelect: () -> Void
    var onPreview: () -> Void

    @State private var isHovered = false

    var body: some View {
        ClipboardBrowserRow(item: item, previewText: previewText, tags: tagInfos,
                            isSelected: isSelected, isHovered: isHovered) {
            if isSelected { ClipboardRowPreviewButton(action: onPreview) }
        }
        .onTapGesture(perform: onSelect)
        .accessibilityAction(named: Text("Select"), onSelect)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            isHovered = hovering
        }
        .overlay {
            ClipboardItemMenu(item: item, tagInfos: tagInfos, allTags: allTags, customActions: customActions,
                              onDelete: onDelete, onTogglePin: onTogglePin, onTagChanged: onTagChanged)
        }
    }
}

struct ClipboardItemMenu: View {
    @Environment(\.modelContext) private var modelContext

    let item: ClipboardItem
    let tagInfos: [TagInfo]
    let allTags: [Tag]
    let customActions: [ContextAction]
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onTagChanged: (() -> Void)?
    var popupTags = true

    var body: some View {
        RightClickReceiver(menuBuilder: buildContextMenu)
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Primary actions
        addAction(to: menu, title: "Copy") { item.payload.write(to: .general) }
        addAction(to: menu, title: item.isPinned ? "Unpin" : "Pin", action: onTogglePin)

        menu.addItem(.separator())

        // MenuBarExtra needs flat tag actions; the modal keeps its tag submenu.
        let tagMenu = popupTags ? menu : NSMenu()
        if !popupTags {
            let parent = NSMenuItem(title: "Tag as...", action: nil, keyEquivalent: "")
            parent.submenu = tagMenu
            menu.addItem(parent)
        }
        for tag in allTags {
            let isTagged = tagInfos.contains { $0.id == tag.id }
            let title = popupTags ? (isTagged ? "✓ \(tag.name)" : "    \(tag.name)") : tag.name
            let action = addAction(to: tagMenu, title: title) { toggleTag(tag, on: item) }
            if !popupTags { action.state = isTagged ? .on : .off }
        }
        addAction(to: tagMenu, title: "+ New Tag...", action: presentNewTagAlert)

        menu.addItem(.separator())

        // Copy As... submenu
        let copyAsSubmenu = NSMenu()
        let copyAsItem = NSMenuItem(title: "Copy As...", action: nil, keyEquivalent: "")
        copyAsItem.submenu = copyAsSubmenu

        addAction(to: copyAsSubmenu, title: "Plain Text") { copyTransformed(item.content) }
        addAction(to: copyAsSubmenu, title: "Uppercase") { copyTransformed(item.content.uppercased()) }
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

    @discardableResult
    private func addAction(to menu: NSMenu, title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.representedObject = action as () -> Void
        item.target = ContextMenuActionTarget.shared
        item.action = #selector(ContextMenuActionTarget.performAction(_:))
        menu.addItem(item)
        return item
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
