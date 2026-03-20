import SwiftUI
import SwiftData
import AppKit

/// Individual row view for an item in the overlay clipboard list.
/// Displays a truncated content preview, optional source app, and relative timestamp.
/// Selection highlight is drawn inline (not via List) so it works when the search field
/// holds first-responder status and the list itself is never focused.
struct OverlayItemRow: View {

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]

    let item: ClipboardItem
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var isEditing: Bool = false     // true when THIS row is currently being edited

    @State private var isHovered = false
    @State private var showNewTagAlert = false

    private var theme: Theme { themeManager.current }

    private var previewText: String {
        DisplayFormatter.format(item.content, maxLength: 100, patterns: [])
    }

    private var relativeTime: String {
        let interval = Date().timeIntervalSince(item.timestamp)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)  // Brand color — not themed
                }
                Text(previewText)
                    .lineLimit(1)
                    .font(.system(size: theme.bodyFontSize, weight: theme.titleFontWeight))
                    .foregroundColor(isSelected ? .white : theme.primaryText)

                Spacer()

                // Pencil icon — always present for hit-testing, opacity-driven visibility
                Button(action: { onEdit?() }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.85) : theme.accentColor)
                }
                .buttonStyle(.plain)
                .opacity((isSelected || isHovered) && !isEditing ? 1 : 0)
            }
            HStack {
                if let sourceApp = item.sourceApp {
                    Text(sourceApp)
                        .font(.caption2)
                        .foregroundColor(isSelected ? Color.white.opacity(0.75) : theme.secondaryText)
                }
                TagBadgesRow(
                    tags: item.tags,
                    isSelected: isSelected,
                    overflowColor: isSelected ? .white.opacity(0.75) : theme.secondaryText
                )
                Spacer()
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundColor(isSelected ? Color.white.opacity(0.75) : theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, theme.itemVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.itemCornerRadius)
                .fill(isSelected ? theme.itemBackground : isHovered ? theme.primaryText.opacity(0.08) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleTap?()
        }
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            onTap?()
        })
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") {
                item.isPinned.toggle()
                try? modelContext.save()
            }

            Divider()

            Menu("Tag as...") {
                ForEach(allTags) { tag in
                    Button(action: { toggleTag(tag, on: item) }) {
                        HStack {
                            Text(tag.name)
                            if item.tags.contains(where: { $0.id == tag.id }) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button("+ New Tag...") {
                    showNewTagAlert = true
                }
            }

            Divider()

            Button("Delete", role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
            }
        }
        .onChange(of: showNewTagAlert) { _, newValue in
            if newValue {
                presentNewTagAlert()
            }
        }
    }

    // MARK: - Tag Actions

    private func toggleTag(_ tag: Tag, on item: ClipboardItem) {
        if let index = item.tags.firstIndex(where: { $0.id == tag.id }) {
            item.tags.remove(at: index)
        } else {
            item.tags.append(tag)
        }
        try? modelContext.save()
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
            }
        }
        showNewTagAlert = false
    }
}
