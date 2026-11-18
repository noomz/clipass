import SwiftUI
import SwiftData
import AppKit

/// Individual row view for an item in the overlay clipboard list.
/// Displays a truncated content preview, optional source app, and relative timestamp.
/// Selection highlight is drawn inline (not via List) so it works when the search field
/// holds first-responder status and the list itself is never focused.
///
/// Performance: accepts pre-computed display data (preview, tags) from parent.
/// No @Query, no SwiftData relationship access, no expensive computation during render.
struct OverlayItemRow: View {

    @FocusState private var editFocused: Bool
    @Environment(\.clipboardBrowserStyle) private var style
    @Environment(\.modelContext) private var modelContext

    let item: ClipboardItem
    let previewText: String        // Pre-computed by parent
    let tagInfos: [TagInfo]        // From TagLookup — no DB access
    let allTags: [Tag]             // For context menu — fetched once by parent
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onPreview: () -> Void
    var onEdit: (() -> Void)? = nil
    var isEditing: Bool = false
    var onTagChanged: (() -> Void)? = nil  // Notify parent to refresh TagLookup

    @State private var isHovered = false
    @State private var showNewTagAlert = false

    var body: some View {
        ClipboardBrowserRow(item: item, previewText: previewText, tags: tagInfos,
                            isSelected: isSelected, isHovered: isHovered) {
            if isSelected && !isEditing { ClipboardRowPreviewButton(action: onPreview) }
            if let onEdit, (isSelected || isHovered || editFocused) && !isEditing {
                Button(action: onEdit) {
                    ClipboardBrowserIcon(symbol: "pencil")
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder((isSelected ? style.selectedInk : style.muted).opacity(editFocused ? 1 : 0.4),
                                              lineWidth: editFocused ? 2 : 1)
                        }
                }
                .buttonStyle(.plain)
                .focused($editFocused)
                .help("Edit item")
                .accessibilityLabel("Edit item")
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    let isTagged = tagInfos.contains { $0.id == tag.id }
                    Button(action: { toggleTag(tag, on: item) }) {
                        HStack {
                            Text(tag.name)
                            if isTagged {
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
                // Delay to let context menu fully dismiss before presenting NSAlert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    presentNewTagAlert()
                }
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
        showNewTagAlert = false
    }
}
