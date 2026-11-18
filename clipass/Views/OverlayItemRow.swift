import SwiftUI

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

    let item: ClipboardItem
    let previewText: String        // Pre-computed by parent
    let tagInfos: [TagInfo]        // From TagLookup — no DB access
    let allTags: [Tag]             // For context menu — fetched once by parent
    let customActions: [ContextAction]
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onPreview: () -> Void
    var onEdit: (() -> Void)? = nil
    var isEditing: Bool = false
    var onTagChanged: (() -> Void)? = nil  // Notify parent to refresh TagLookup

    @State private var isHovered = false

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
        .overlay {
            ClipboardItemMenu(item: item, tagInfos: tagInfos, allTags: allTags, customActions: customActions,
                              onDelete: onDelete, onTogglePin: onTogglePin, onTagChanged: onTagChanged, popupTags: false)
        }
    }
}
