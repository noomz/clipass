import SwiftUI
import SwiftData

/// Root SwiftUI view for the overlay panel content.
/// Hosts a search field, filtered clipboard list with keyboard navigation,
/// vibrancy background, and smooth show/hide animation.
struct ClipboardOverlayView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]

    @State private var searchText = ""
    @State private var selectedID: ClipboardItem.ID?
    @State private var showContent = false
    @State private var editingItemID: ClipboardItem.ID? = nil
    @State private var editorContent: String = ""

    // MARK: - Theme Convenience

    private var theme: Theme { themeManager.current }

    // MARK: - Filtered Items

    /// Items sorted with pinned first, then by timestamp descending, filtered by search text.
    /// Supports `tag:name` prefix tokens: multiple tag tokens use OR logic,
    /// combined with free text via AND (e.g. `tag:work hello` = tagged 'work' AND contains 'hello').
    private var filteredItems: [ClipboardItem] {
        let sorted = items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.timestamp > b.timestamp
        }
        guard !searchText.isEmpty else { return sorted }

        // Parse tag: tokens
        let tokens = searchText.split(separator: " ").map(String.init)
        let tagTokens = tokens
            .filter { $0.lowercased().hasPrefix("tag:") }
            .map { String($0.dropFirst(4)).lowercased() }
        let textTokens = tokens
            .filter { !$0.lowercased().hasPrefix("tag:") }
            .joined(separator: " ")

        return sorted.filter { item in
            // Tag filter: any tag token matches (OR logic)
            let tagMatch: Bool
            if tagTokens.isEmpty {
                tagMatch = true
            } else {
                tagMatch = tagTokens.contains { tagName in
                    item.tags.contains { $0.name.lowercased() == tagName }
                }
            }
            // Text filter: remaining text must match content
            let textMatch: Bool
            if textTokens.isEmpty {
                textMatch = true
            } else {
                textMatch = item.content.localizedCaseInsensitiveContains(textTokens)
            }
            return tagMatch && textMatch
        }
    }

    // MARK: - Themed Divider

    @ViewBuilder private var themedDivider: some View {
        switch theme.dividerStyle {
        case .standard:
            Rectangle()
                .fill(theme.dividerColor)
                .frame(height: 1)
        case .thick:
            Rectangle()
                .fill(theme.dividerColor)
                .frame(height: 2)
        case .none:
            EmptyView()
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Theme-driven background — vibrancy, tinted vibrancy, or solid
            VisualEffectView(
                backgroundMode: theme.backgroundMode,
                forceAppearance: theme.forceAppearance,
                solidColor: NSColor(theme.overlayBackground)
            )
            .id(theme.backgroundMode.discriminator)

            // Content with animation
            if showContent {
                contentStack
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.15), value: showContent)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .frame(width: 640, height: 400)
        .onAppear {
            showContent = true
            if selectedID == nil {
                selectedID = filteredItems.first?.id
            }
            // Register ESC guard with the panel (Pitfall 7 fix):
            // If EditorTextView loses first-responder and user presses ESC,
            // OverlayPanel.cancelOperation fires. This handler intercepts it
            // and cancels the editor instead of dismissing the overlay.
            OverlayWindowController.shared.panel.cancelEditHandler = {
                if self.editingItemID != nil {
                    self.cancelEdit()
                    return true
                }
                return false
            }
        }
        // Reset search and edit state when overlay is about to show.
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("overlayWillShow"))) { _ in
            searchText = ""
            editingItemID = nil
            editorContent = ""
            showContent = true
        }
        // Auto-select first item whenever filtered list changes
        .onChange(of: filteredItems) { _, newItems in
            if selectedID == nil || !newItems.contains(where: { $0.id == selectedID }) {
                selectedID = newItems.first?.id
            }
        }
    }

    // MARK: - Content Stack

    private var contentStack: some View {
        VStack(spacing: 0) {
            // Search field — custom NSViewRepresentable handles:
            //   • Auto-focus (requests first-responder immediately)
            //   • Arrow key interception (↑/↓ move list selection)
            //   • ESC interception (dismisses overlay, or cancels editor if editing)
            //   • Return interception (pastes selected item)
            // Arrow keys and Return are no-ops while the editor is open.
            // ESC two-stage routing: cancel editor first, then dismiss overlay.
            OverlaySearchField(
                text: $searchText,
                placeholder: "Search clipboard...",
                theme: theme,
                shouldRefocus: editingItemID == nil,
                onArrowUp: editingItemID == nil ? moveSelectionUp : {},
                onArrowDown: editingItemID == nil ? moveSelectionDown : {},
                onEscape: {
                    if editingItemID != nil {
                        cancelEdit()
                    } else {
                        OverlayWindowController.shared.hide()
                    }
                },
                onReturn: editingItemID == nil ? pasteSelected : {}
            )
            .frame(height: 44)
            .padding(.horizontal, 12)
            .disabled(editingItemID != nil)
            .opacity(editingItemID != nil ? 0.5 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: theme.itemCornerRadius)
                    .fill(theme.searchFieldBackground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            )

            themedDivider

            // Clipboard list — selection and scroll position are driven entirely by selectedID.
            // Arrow key events are handled by OverlaySearchField and update selectedID;
            // the ScrollViewReader auto-scrolls to keep the selected row visible.
            // Using ScrollView+ForEach (not List) so selection highlight renders correctly
            // even when the search field — not the list — holds first-responder status.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            OverlayItemRow(
                                item: item,
                                isSelected: item.id == selectedID,
                                onTap: {
                                    selectedID = item.id
                                },
                                onDoubleTap: {
                                    selectedID = item.id
                                    pasteSelected()
                                },
                                onEdit: {
                                    selectedID = item.id
                                    enterEditMode(for: item)
                                },
                                isEditing: item.id == editingItemID
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedID) { _, newID in
                    if let id = newID {
                        withAnimation(.linear(duration: 0.1)) {
                            proxy.scrollTo(id, anchor: nil)
                        }
                    }
                }
            }

            // Bottom section: inline editor panel when editing, otherwise item count bar.
            // withAnimation in enter/commit/cancel functions drives the slide transition.
            if let editingID = editingItemID,
               filteredItems.first(where: { $0.id == editingID }) != nil {

                themedDivider

                InlineEditorPanel(
                    content: $editorContent,
                    theme: theme,
                    onSave: commitEdit,
                    onCancel: cancelEdit
                )
                .frame(height: 160)
                .transition(.move(edge: .bottom).combined(with: .opacity))

            } else {
                themedDivider

                // Bottom bar — item count
                HStack {
                    Spacer()
                    Text("\(filteredItems.count) item\(filteredItems.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: editingItemID)
    }

    // MARK: - Keyboard Actions

    private func moveSelectionDown() {
        guard !filteredItems.isEmpty else { return }
        if let current = selectedID,
           let idx = filteredItems.firstIndex(where: { $0.id == current }),
           idx + 1 < filteredItems.count {
            selectedID = filteredItems[idx + 1].id
        } else {
            selectedID = filteredItems.first?.id
        }
    }

    private func moveSelectionUp() {
        guard !filteredItems.isEmpty else { return }
        if let current = selectedID,
           let idx = filteredItems.firstIndex(where: { $0.id == current }),
           idx > 0 {
            selectedID = filteredItems[idx - 1].id
        } else {
            selectedID = filteredItems.last?.id
        }
    }

    private func pasteSelected() {
        guard let selectedID,
              let item = filteredItems.first(where: { $0.id == selectedID }) else { return }
        OverlayWindowController.shared.pasteAndHide(content: item.content)
    }

    // MARK: - Edit Actions

    private func enterEditMode(for item: ClipboardItem) {
        editorContent = item.content    // raw content, NOT DisplayFormatter output (Pitfall 6)
        withAnimation(.easeOut(duration: 0.15)) {
            editingItemID = item.id
        }
    }

    private func commitEdit() {
        guard let id = editingItemID,
              let item = filteredItems.first(where: { $0.id == id }) else {
            cancelEdit()
            return
        }
        item.content = editorContent
        try? modelContext.save()
        // Remove editor view first, then clear content on next runloop
        // to avoid updateNSView + gutter redraw during teardown
        withAnimation(.easeOut(duration: 0.15)) {
            editingItemID = nil
        }
        DispatchQueue.main.async {
            editorContent = ""
        }
        // selectedID remains unchanged — edited item stays highlighted
    }

    private func cancelEdit() {
        // Set editingItemID = nil first to remove the editor view,
        // THEN clear editorContent. Clearing content while the view is still
        // mounted triggers updateNSView + gutter redraw during teardown → crash.
        withAnimation(.easeOut(duration: 0.15)) {
            editingItemID = nil
        }
        // Defer content clear to after the view is removed from the hierarchy
        DispatchQueue.main.async {
            editorContent = ""
        }
        // selectedID unchanged — item remains selected after cancel
    }
}
