import SwiftUI
import SwiftData

/// Root SwiftUI view for the overlay panel content.
/// Hosts a search field, filtered clipboard list with keyboard navigation,
/// vibrancy background, and smooth show/hide animation.
///
/// Performance strategy:
/// - `sortedItems` cached as @State, rebuilt only when @Query items change
/// - `displayItems` (filtered) cached as @State, rebuilt only on debounced search
/// - `tagLookup` pre-computes all tag data from Tag side (few faults) not Item side
/// - Row previews pre-computed once per filter cycle, not per-row per-render
struct ClipboardOverlayView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]

    @State private var searchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var selectedID: ClipboardItem.ID?
    @State private var showContent = false
    @State private var editingItemID: ClipboardItem.ID? = nil
    @State private var editorContent: String = ""

    // Cached data — rebuilt on specific triggers, not every render
    @State private var sortedItems: [ClipboardItem] = []
    @State private var displayItems: [ClipboardItem] = []
    @State private var tagLookup: TagLookup = .empty
    @State private var allTags: [Tag] = []
    @State private var previewCache: [UUID: String] = [:]

    // MARK: - Theme Convenience

    private var theme: Theme { themeManager.current }

    // MARK: - Rebuild Helpers

    private func rebuildSorted() {
        let t = Date()
        sortedItems = items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.timestamp > b.timestamp
        }
        print("[PERF] rebuildSorted: \(Date().timeIntervalSince(t)*1000)ms, \(items.count) items")
    }

    private func rebuildDisplay(search: String) {
        guard !search.isEmpty else {
            displayItems = sortedItems
            updateSelection()
            return
        }

        let tokens = search.split(separator: " ").map(String.init)
        let tagNames = tokens
            .filter { $0.lowercased().hasPrefix("tag:") }
            .compactMap { token -> String? in
                let name = String(token.dropFirst(4)).lowercased()
                return name.isEmpty ? nil : name
            }
        let freeText = tokens
            .filter { !$0.lowercased().hasPrefix("tag:") }
            .joined(separator: " ")

        displayItems = sortedItems.filter { item in
            let tagMatch: Bool
            if tagNames.isEmpty {
                tagMatch = true
            } else {
                // Use pre-computed tagLookup — zero DB access
                tagMatch = tagNames.contains { name in
                    tagLookup.itemIDsByTag[name]?.contains(item.id) == true
                }
            }
            let textMatch: Bool
            if freeText.isEmpty {
                textMatch = true
            } else {
                textMatch = item.content.localizedCaseInsensitiveContains(freeText)
            }
            return tagMatch && textMatch
        }
        updateSelection()
    }

    private func updateSelection() {
        if selectedID == nil || !displayItems.contains(where: { $0.id == selectedID }) {
            selectedID = displayItems.first?.id
        }
    }

    private func refreshTagLookup() {
        let t = Date()
        tagLookup = TagLookup.build(from: modelContext)
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        allTags = (try? modelContext.fetch(descriptor)) ?? []
        print("[PERF] refreshTagLookup: \(Date().timeIntervalSince(t)*1000)ms")
    }

    private func previewText(for item: ClipboardItem) -> String {
        if let cached = previewCache[item.id] { return cached }
        let text = DisplayFormatter.format(item.content, maxLength: 100, patterns: [])
        previewCache[item.id] = text
        return text
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
        let _ = {
            let t = Date()
            print("[PERF] body eval start, items=\(items.count), display=\(displayItems.count), search='\(searchText)'")
            DispatchQueue.main.async { print("[PERF] body eval took \(Date().timeIntervalSince(t)*1000)ms") }
        }()
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
            refreshTagLookup()
            rebuildSorted()
            rebuildDisplay(search: "")
            // Register ESC guard with the panel (Pitfall 7 fix):
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
            previewCache = [:]
            refreshTagLookup()
            rebuildSorted()
            rebuildDisplay(search: "")
        }
        // When @Query items change (new clip, delete, edit), rebuild sorted + display
        .onChange(of: items) { _, _ in
            previewCache = [:]
            rebuildSorted()
            rebuildDisplay(search: searchText)
        }
        // Debounce search — 150ms after last keystroke
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            if newValue.isEmpty {
                rebuildDisplay(search: "")
            } else {
                searchDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    guard !Task.isCancelled else { return }
                    rebuildDisplay(search: newValue)
                }
            }
        }
    }

    // MARK: - Content Stack

    private var contentStack: some View {
        VStack(spacing: 0) {
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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayItems) { item in
                            OverlayItemRow(
                                item: item,
                                previewText: previewText(for: item),
                                tagInfos: tagLookup.tagsByItem[item.id] ?? [],
                                allTags: allTags,
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
                                isEditing: item.id == editingItemID,
                                onTagChanged: {
                                    refreshTagLookup()
                                    rebuildDisplay(search: searchText)
                                }
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
            if let editingID = editingItemID,
               displayItems.first(where: { $0.id == editingID }) != nil {

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
                    Text("\(displayItems.count) item\(displayItems.count == 1 ? "" : "s")")
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
        guard !displayItems.isEmpty else { return }
        if let current = selectedID,
           let idx = displayItems.firstIndex(where: { $0.id == current }),
           idx + 1 < displayItems.count {
            selectedID = displayItems[idx + 1].id
        } else {
            selectedID = displayItems.first?.id
        }
    }

    private func moveSelectionUp() {
        guard !displayItems.isEmpty else { return }
        if let current = selectedID,
           let idx = displayItems.firstIndex(where: { $0.id == current }),
           idx > 0 {
            selectedID = displayItems[idx - 1].id
        } else {
            selectedID = displayItems.last?.id
        }
    }

    private func pasteSelected() {
        guard let selectedID,
              let item = displayItems.first(where: { $0.id == selectedID }) else { return }
        OverlayWindowController.shared.pasteAndHide(content: item.content)
    }

    // MARK: - Edit Actions

    private func enterEditMode(for item: ClipboardItem) {
        editorContent = item.content
        withAnimation(.easeOut(duration: 0.15)) {
            editingItemID = item.id
        }
    }

    private func commitEdit() {
        guard let id = editingItemID,
              let item = displayItems.first(where: { $0.id == id }) else {
            cancelEdit()
            return
        }
        item.content = editorContent
        try? modelContext.save()
        withAnimation(.easeOut(duration: 0.15)) {
            editingItemID = nil
        }
        DispatchQueue.main.async {
            editorContent = ""
        }
    }

    private func cancelEdit() {
        withAnimation(.easeOut(duration: 0.15)) {
            editingItemID = nil
        }
        DispatchQueue.main.async {
            editorContent = ""
        }
    }
}
