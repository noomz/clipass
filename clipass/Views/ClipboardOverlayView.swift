import SwiftUI
import SwiftData

struct ClipboardOverlayView: View {
    // Passed in to avoid reaching the controller singleton during NSHostingView initialization.
    unowned let panel: OverlayPanel
    let monitor: ClipboardMonitor
    var onCopyAndClose: (ClipboardPayload) -> Void = { OverlayWindowController.shared.copyAndHide($0) }
    var onDismiss: () -> Void = { OverlayWindowController.shared.hide() }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @Query private var redactionPatterns: [RedactionPattern]
    @Query(sort: \ContextAction.order) private var customActions: [ContextAction]
    @AppStorage("previewMaxLength") private var previewMaxLength = 80

    @State private var browser = ClipboardBrowserState()
    @FocusState private var focusedArea: ClipboardBrowserState.Focus?
    @State private var revealRequest = UUID()
    @State private var scrollAnchor: UUID?
    @State private var showContent = false
    @State private var searchHasFocus = false
    @State private var searchFocusRequest = ClipboardBrowserSearchField.FocusRequest()
    @State private var editingItemID: ClipboardItem.ID?
    @State private var editorContent = ""
    @State private var tagLookup: TagLookup = .empty
    @State private var allTags: [Tag] = []

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
        guard browser.presentation == .list else { return }
        browser.selectItem(id)
        browser.setFocus(.list)
        applyBrowserFocus()
    }

    private func openTab(_ tab: ClipboardBrowserState.Tab) {
        browser.openTab(tab)
        editingItemID = nil
        editorContent = ""
        applyBrowserFocus()
        revealRequest = UUID()
    }

    private func applyBrowserFocus(selectQuery: Bool = false) {
        focusedArea = browser.focus
        searchFocusRequest = .init(intent: browser.focus == .search ? (selectQuery ? .selectAll : .focus) : .resign)
    }

    private func handleKey(_ action: ClipboardBrowserState.Action, focus: ClipboardBrowserState.Focus) -> Bool {
        if editingItemID != nil {
            switch action {
            case .back:
                cancelEdit()
                focusedArea = .list
                return true
            case .openTab, .cycleTab:
                cancelEdit()
            default:
                return false
            }
        }
        switch browser.handleKeyboard(action, focus: focus) {
        case .passThrough: return false
        case .dismiss: onDismiss()
        case .copyAndClose(let id): copyAndClose(id)
        case .update(let focus, let reveal):
            if focus { applyBrowserFocus(selectQuery: action == .focusSearch) }
            if reveal { revealRequest = UUID() }
        }
        return true
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
        refreshTagLookup()
        browser.summon(items: browserItems)
        applyBrowserFocus()
        scrollAnchor = browser.selectedID
        revealRequest = UUID()
    }

    private func previewText(for item: ClipboardItem) -> String {
        DisplayFormatter.format(item.content, maxLength: previewMaxLength, patterns: redactionPatterns)
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
        .clipboardDragHost()
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .environment(\.clipboardBrowserStyle, style)
        .onAppear {
            showContent = true
            summon()
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlayWillShow, object: panel)) { _ in
            summon()
        }
        .onReceive(monitor.captures) {
            if panel.isVisible { browser.noteCapture() }
        }
        .onChange(of: browserItems) { _, snapshots in
            let focus = browser.focus
            browser.replaceItems(snapshots)
            if focus != browser.focus { applyBrowserFocus() }
        }
    }

    private var contentFocus: ClipboardBrowserState.Focus {
        switch focusedArea {
        case .list: .list
        case .preview: .preview
        default: .control
        }
    }
    private var inputFocus: ClipboardBrowserState.Focus { searchHasFocus ? .search : contentFocus }

    private func togglePreview() { _ = handleKey(.togglePreview, focus: inputFocus) }

    private func searchFocusChanged(_ focused: Bool) {
        searchHasFocus = focused
        if focused, browser.transientLayer == nil { browser.setFocus(.search) }
    }

    private func closeHelp() { _ = handleKey(.toggleHelp, focus: .control) }

    private var contentStack: some View {
        let results = displayItems
        let selected = results.first { $0.id == selectedID }
        let isPreviewing = browser.presentation == .preview
        return VStack(spacing: 0) {
            ClipboardBrowserTitleBar(title: "Clipboard history") {
                ClipboardBrowserOverflow(canClear: items.contains { !$0.isPinned }, confirmClear: confirmClear) {}
                    .disabled(editingItemID != nil)
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
                    .clipboardPreview(isPreviewing ? selected : nil, tags: tagLookup.tagsByItem,
                                      patterns: redactionPatterns, focus: $focusedArea)
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
                                       focus: inputFocus, hasQuery: !browser.query.isEmpty,
                                       isPreviewing: isPreviewing, togglePreview: togglePreview, copy: copySelectedAndClose,
                                       unseenCaptureCount: browser.unseenCaptureCount, jumpToLatest: summon)
            }
        }
        .clipboardShortcutHelp(isPresented: browser.transientLayer == .help, close: closeHelp)
        .modifier(ClipboardBrowserHistoryControls(isConfirming: browser.transientLayer == .confirmation,
                                                  dismissConfirmation: dismissConfirmation, historyChanged: refreshTagLookup))
        .background { ClipboardBrowserKeyboard(focus: contentFocus, action: handleKey) }
        .animation(.easeOut(duration: 0.15), value: editingItemID)
    }

    private var searchBar: some View {
        ClipboardBrowserSearch(query: browser.query, focused: editingItemID == nil && searchHasFocus, onClear: clearSearch) {
            ClipboardBrowserSearchField(
                text: searchText,
                textColor: theme.id == .system ? style.ink : theme.searchFieldText,
                placeholderColor: theme.id == .system ? style.muted : theme.searchFieldPlaceholder,
                fontSize: theme.bodyFontSize,
                focusRequest: searchFocusRequest,
                onFocusChange: searchFocusChanged
            )
            .frame(height: 20)
        }
        .disabled(editingItemID != nil)
        .opacity(editingItemID != nil ? 0.5 : 1)
    }

    private func confirmClear() {
        browser.showLayer(.confirmation)
        focusedArea = nil
        searchFocusRequest = .init(intent: .resign)
    }

    private func dismissConfirmation() { _ = handleKey(.back, focus: .control) }

    private func clearSearch() {
        searchText.wrappedValue = ""
        browser.setFocus(.search)
        applyBrowserFocus()
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
                            customActions: customActions,
                            onDelete: {
                                if editingItemID == item.id { cancelEdit() }
                                modelContext.delete(item)
                                try? modelContext.save()
                            },
                            onTogglePin: {
                                item.isPinned.toggle()
                                try? modelContext.save()
                            },
                            isSelected: item.id == selectedID,
                            onTap: { selectItem(item.id) },
                            onDoubleTap: {
                                selectItem(item.id)
                                copySelectedAndClose()
                            },
                            onPreview: togglePreview,
                            onEdit: item.isImage ? nil : {
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

    private func copySelectedAndClose() {
        if let id = browser.selectedItem?.id { copyAndClose(id) }
    }

    private func copyAndClose(_ id: UUID) {
        if let item = items.first(where: { $0.id == id }) { onCopyAndClose(item.payload) }
    }

    private func enterEditMode(for item: ClipboardItem) {
        guard !item.isImage else { return }
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
