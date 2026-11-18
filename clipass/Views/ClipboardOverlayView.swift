import SwiftUI
import SwiftData

struct ClipboardOverlayView: View {
    // Passed in to avoid reaching the controller singleton during NSHostingView initialization.
    unowned let panel: OverlayPanel
    let monitor: ClipboardMonitor
    var onCopyAndClose: (String) -> Void = { OverlayWindowController.shared.pasteAndHide(content: $0) }
    var onDismiss: () -> Void = { OverlayWindowController.shared.hide() }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]

    @State private var browser = ClipboardBrowserState()
    @FocusState private var focusedArea: ClipboardBrowserState.Focus?
    @State private var revealRequest = UUID()
    @State private var scrollAnchor: UUID?
    @State private var showContent = false
    @State private var searchHasFocus = false
    @State private var searchFocusRequest = UUID()
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
        if browser.focus == .search { searchFocusRequest = UUID() }
        revealRequest = UUID()
    }

    private func refreshTagLookup() {
        tagLookup = TagLookup.build(from: modelContext)
        browser.replaceItems(browserItems)
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        allTags = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func summon() {
        editingItemID = nil
        editorContent = ""
        previewCache = [:]
        refreshTagLookup()
        browser.summon(items: browserItems)
        focusedArea = .search
        searchFocusRequest = UUID()
        scrollAnchor = browser.selectedID
        revealRequest = UUID()
    }

    private func previewText(for item: ClipboardItem) -> String {
        if let cached = previewCache[item.id] { return cached }
        let text = DisplayFormatter.format(item.content, maxLength: 100, patterns: [])
        previewCache[item.id] = text
        return text
    }

    private var style: ClipboardBrowserStyle {
        ClipboardBrowserStyle(compact: false, scheme: colorScheme, theme: theme)
    }

    var body: some View {
        ZStack {
            if theme.id == .system {
                style.surface
            } else {
                VisualEffectView(
                    backgroundMode: theme.backgroundMode,
                    forceAppearance: theme.forceAppearance,
                    solidColor: NSColor(theme.overlayBackground)
                )
                .id(theme.backgroundMode.discriminator)
            }

            if showContent {
                contentStack
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.15), value: showContent)
            }
        }
        .frame(width: ClipboardBrowserStyle.overlaySize.width, height: ClipboardBrowserStyle.overlaySize.height)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .environment(\.clipboardBrowserStyle, style)
        .onAppear {
            showContent = true
            summon()
            panel.cancelEditHandler = {
                if self.editingItemID != nil {
                    self.cancelEdit()
                    return true
                }
                return false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlayWillShow, object: panel)) { _ in
            summon()
        }
        .onReceive(monitor.captures) {
            if panel.isVisible { browser.noteCapture() }
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
        let results = displayItems
        let selected = results.first { $0.id == selectedID }
        return VStack(spacing: 0) {
            ClipboardBrowserTitleBar(title: "Clipboard history") {
                Button(action: onDismiss) { ClipboardBrowserIcon(symbol: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundStyle(style.muted)
                    .help("Close clipboard history")
                    .accessibilityLabel("Close clipboard history")
            }
            searchBar
            ClipboardBrowserTabs(tab: browser.tab, recentCount: items.count,
                                 pinnedCount: items.filter(\.isPinned).count, onSelect: openTab)
            ClipboardBrowserSection(tab: browser.tab, isSearching: !browser.query.isEmpty, count: results.count)
            if let emptyState = browser.emptyState {
                ClipboardBrowserEmptyView(state: emptyState, query: browser.query, clearSearch: clearSearch)
            } else {
                historyList(results)
            }

            if let editingID = editingItemID, results.contains(where: { $0.id == editingID }) {
                InlineEditorPanel(
                    content: $editorContent,
                    theme: theme,
                    onSave: commitEdit,
                    onCancel: cancelEdit
                )
                .frame(height: 160)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                ClipboardBrowserFooter(selectedText: selected.map { previewText(for: $0) },
                                       hasSelection: selected != nil, count: results.count,
                                       focus: browser.focus, copy: pasteSelected,
                                       unseenCaptureCount: browser.unseenCaptureCount, jumpToLatest: summon)
            }
        }
        .animation(.easeOut(duration: 0.15), value: editingItemID)
    }

    private var searchBar: some View {
        ClipboardBrowserSearch(query: browser.query, focused: editingItemID == nil && searchHasFocus, onClear: clearSearch) {
            OverlaySearchField(
                text: searchText,
                placeholder: "Text or tag:work",
                textColor: theme.id == .system ? style.ink : theme.searchFieldText,
                placeholderColor: theme.id == .system ? style.muted : theme.searchFieldPlaceholder,
                fontSize: theme.bodyFontSize,
                focusRequest: searchFocusRequest,
                onFocus: {
                    browser.setFocus(.search)
                    focusedArea = .search
                },
                onFocusChange: { searchHasFocus = $0 },
                onArrowUp: editingItemID == nil ? moveSelectionUp : {},
                onArrowDown: editingItemID == nil ? moveSelectionDown : {},
                onEscape: {
                    if editingItemID != nil { cancelEdit() } else { onDismiss() }
                },
                onReturn: editingItemID == nil ? pasteSelected : {}
            )
            .frame(height: 20)
        }
        .disabled(editingItemID != nil)
        .opacity(editingItemID != nil ? 0.5 : 1)
    }

    private func clearSearch() {
        searchText.wrappedValue = ""
        browser.setFocus(.search)
        focusedArea = .search
        searchFocusRequest = UUID()
    }

    private func historyList(_ results: [ClipboardItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
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
                        .overlay(alignment: .bottom) {
                            style.rowSeparator(below: index, in: results, selectedID: selectedID)
                                .allowsHitTesting(false)
                        }
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollAnchor, anchor: .top)
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
                if let id = selectedID { proxy.scrollTo(id, anchor: .top) }
            }
            .onChange(of: revealRequest) { _, _ in
                if let id = selectedID { proxy.scrollTo(id, anchor: .top) }
            }
            .onChange(of: selectedID) { _, newID in
                if let id = newID, id != scrollAnchor {
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
