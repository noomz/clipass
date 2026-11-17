import SwiftUI
import SwiftData

struct ClipboardOverlayView: View {
    // Passed in to avoid reaching the controller singleton during NSHostingView initialization.
    unowned let panel: OverlayPanel
    var onCopyAndClose: (String) -> Void = { OverlayWindowController.shared.pasteAndHide(content: $0) }

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]

    @State private var browser = ClipboardBrowserState()
    @FocusState private var focusedArea: ClipboardBrowserState.Focus?
    @State private var revealRequest = UUID()
    @State private var showContent = false
    @State private var editingItemID: ClipboardItem.ID?
    @State private var editorContent = ""
    @State private var tagLookup: TagLookup = .empty
    @State private var allTags: [Tag] = []
    @State private var previewCache: [UUID: String] = [:]

    private var theme: Theme { themeManager.current }
    private var selectedID: UUID? { browser.selectedID }

    private var browserItems: [ClipboardBrowserState.Item] {
        items.map { ClipboardBrowserState.Item($0, tagLookup: tagLookup) }
    }

    private var displayItems: [ClipboardItem] {
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return browser.visibleItems.compactMap { byID[$0.id] }
    }

    private var searchText: Binding<String> {
        Binding(get: { browser.query }, set: {
            browser.setQuery($0)
            revealRequest = UUID()
        })
    }

    private func selectItem(_ id: UUID) {
        browser.selectItem(id)
        browser.setFocus(.list)
        focusedArea = .list
    }

    private func openTab(_ tab: ClipboardBrowserState.Tab) {
        browser.openTab(tab)
        editingItemID = nil
        editorContent = ""
        focusedArea = browser.focus
        revealRequest = UUID()
    }

    private func refreshTagLookup() {
        tagLookup = TagLookup.build(from: modelContext)
        browser.replaceItems(browserItems)
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        allTags = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func previewText(for item: ClipboardItem) -> String {
        if let cached = previewCache[item.id] { return cached }
        let text = DisplayFormatter.format(item.content, maxLength: 100, patterns: [])
        previewCache[item.id] = text
        return text
    }

    @ViewBuilder private var themedDivider: some View {
        switch theme.dividerStyle {
        case .standard:
            Rectangle().fill(theme.dividerColor).frame(height: 1)
        case .thick:
            Rectangle().fill(theme.dividerColor).frame(height: 2)
        case .none:
            EmptyView()
        }
    }

    var body: some View {
        ZStack {
            VisualEffectView(
                backgroundMode: theme.backgroundMode,
                forceAppearance: theme.forceAppearance,
                solidColor: NSColor(theme.overlayBackground)
            )
            .id(theme.backgroundMode.discriminator)

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
            panel.cancelEditHandler = {
                if self.editingItemID != nil {
                    self.cancelEdit()
                    return true
                }
                return false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("overlayWillShow"))) { _ in
            browser.setQuery("")
            editingItemID = nil
            editorContent = ""
            showContent = true
            previewCache = [:]
            refreshTagLookup()
        }
        .onChange(of: browserItems) { _, snapshots in
            previewCache = [:]
            browser.replaceItems(snapshots)
        }
        .onChange(of: focusedArea) { _, focus in
            if let focus { browser.setFocus(focus) }
        }
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            ClipboardBrowserTabs(tab: browser.tab, onSelect: openTab)
                .padding(.top, 8)

            OverlaySearchField(
                text: searchText,
                placeholder: "Search text or tag:work",
                theme: theme,
                shouldRefocus: editingItemID == nil && browser.focus == .search,
                onFocus: {
                    browser.setFocus(.search)
                    focusedArea = .search
                },
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

            if let emptyState = browser.emptyState {
                ClipboardBrowserEmptyView(state: emptyState) {
                    searchText.wrappedValue = ""
                    browser.setFocus(.search)
                    focusedArea = .search
                }
            } else {
                historyList
            }

            themedDivider

            if let editingID = editingItemID,
               displayItems.contains(where: { $0.id == editingID }) {
                InlineEditorPanel(
                    content: $editorContent,
                    theme: theme,
                    onSave: commitEdit,
                    onCancel: cancelEdit
                )
                .frame(height: 160)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
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

    private var historyList: some View {
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
                            onTap: { selectItem(item.id) },
                            onDoubleTap: {
                                selectItem(item.id)
                                pasteSelected()
                            },
                            onEdit: {
                                selectItem(item.id)
                                enterEditMode(for: item)
                            },
                            isEditing: item.id == editingItemID,
                            onTagChanged: refreshTagLookup
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .focusable()
            .focused($focusedArea, equals: .list)
            .onKeyPress(.return) {
                guard focusedArea == .list, editingItemID == nil else { return .ignored }
                pasteSelected()
                return .handled
            }
            .onMoveCommand { direction in
                switch direction {
                case .up: moveSelectionUp()
                case .down: moveSelectionDown()
                default: break
                }
            }
            .onAppear {
                if let id = selectedID { proxy.scrollTo(id) }
            }
            .onChange(of: revealRequest) { _, _ in
                if let id = selectedID { proxy.scrollTo(id) }
            }
            .onChange(of: selectedID) { _, newID in
                if let id = newID {
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(id, anchor: nil)
                    }
                }
            }
        }
    }

    private func moveSelectionDown() {
        guard !displayItems.isEmpty else { return }
        if let current = selectedID,
           let idx = displayItems.firstIndex(where: { $0.id == current }),
           idx + 1 < displayItems.count {
            selectItem(displayItems[idx + 1].id)
        } else if let id = displayItems.first?.id {
            selectItem(id)
        }
    }

    private func moveSelectionUp() {
        guard !displayItems.isEmpty else { return }
        if let current = selectedID,
           let idx = displayItems.firstIndex(where: { $0.id == current }),
           idx > 0 {
            selectItem(displayItems[idx - 1].id)
        } else if let id = displayItems.last?.id {
            selectItem(id)
        }
    }

    private func pasteSelected() {
        guard let selectedID,
              let item = displayItems.first(where: { $0.id == selectedID }) else { return }
        onCopyAndClose(item.content)
    }

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
        cancelEdit()
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
