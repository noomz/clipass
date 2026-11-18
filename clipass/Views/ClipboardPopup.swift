import SwiftUI
import SwiftData
import AppKit
import KeyboardShortcuts

private let perfLogFile = FileHandle(forWritingAtPath: "/tmp/clipass-popup-perf.log") ?? {
    FileManager.default.createFile(atPath: "/tmp/clipass-popup-perf.log", contents: nil)
    return FileHandle(forWritingAtPath: "/tmp/clipass-popup-perf.log")!
}()

@discardableResult
private func perfLog(_ msg: String) -> Bool {
    let ts = String(format: "%.3f", Date().timeIntervalSince1970)
    let line = "[\(ts)] \(msg)\n"
    perfLogFile.seekToEndOfFile()
    perfLogFile.write(line.data(using: .utf8)!)
    return true
}

struct ClipboardPopup: View {
    var monitor: ClipboardMonitor
    var onCopyAndClose: (String) -> Void = { content in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        ClipboardPopupToggle.toggle()
    }
    var onDismiss: () -> Void = { ClipboardPopupToggle.toggle() }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ClipboardItem.timestamp, order: .reverse)
    private var items: [ClipboardItem]
    @Query private var rules: [TransformRule]
    @Query private var hooks: [Hook]
    @Query private var redactionPatterns: [RedactionPattern]
    @Query(sort: \ContextAction.order) private var customActions: [ContextAction]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var browser = ClipboardBrowserState()
    @FocusState private var focusedArea: ClipboardBrowserState.Focus?
    @State private var searchHasFocus = false
    @State private var searchFocusRequest = ClipboardBrowserSearchField.FocusRequest()
    @State private var revealRequest = UUID()
    @State private var scrollAnchor: UUID?
    @State private var isVisible = false
    @State private var tagLookup: TagLookup = .empty

    @AppStorage("previewMaxLength") private var previewMaxLength = 80

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

    private func openTab(_ tab: ClipboardBrowserState.Tab) {
        browser.openTab(tab)
        applyBrowserFocus()
        revealRequest = UUID()
    }

    private func applyBrowserFocus(selectQuery: Bool = false) {
        focusedArea = browser.focus
        searchFocusRequest = .init(intent: browser.focus == .search ? (selectQuery ? .selectAll : .focus) : .resign)
    }

    private func handleKey(_ action: ClipboardBrowserState.Action, focus: ClipboardBrowserState.Focus) -> Bool {
        switch browser.handleKeyboard(action, focus: focus) {
        case .passThrough: return false
        case .dismiss: onDismiss()
        case .copyAndClose(let content): onCopyAndClose(content)
        case .update(let focus, let reveal):
            if focus { applyBrowserFocus(selectQuery: action == .focusSearch) }
            if reveal { revealRequest = UUID() }
        }
        return true
    }

    private func refreshTagLookup() {
        tagLookup = TagLookup.build(from: modelContext)
        browser.replaceItems(browserItems)
    }

    private func summon() {
        tagLookup = TagLookup.build(from: modelContext)
        browser.summon(items: browserItems)
        applyBrowserFocus()
        scrollAnchor = browser.selectedID
        revealRequest = UUID()
    }

    private func previewText(for item: ClipboardItem) -> String {
        DisplayFormatter.format(item.content, maxLength: previewMaxLength, patterns: redactionPatterns)
    }

    private var style: ClipboardBrowserStyle { ClipboardBrowserStyle(compact: true, scheme: colorScheme) }

    var body: some View {
        let results = displayItems
        let selected = results.first { $0.id == browser.selectedID }
        let isPreviewing = browser.presentation == .preview
        let _ = perfLog("body eval: items=\(items.count), display=\(results.count), search='\(browser.query)'")
        VStack(spacing: 0) {
            titleBar
            ClipboardBrowserSearch(query: browser.query, focused: searchHasFocus, onClear: clearSearch) {
                ClipboardBrowserSearchField(text: searchText, textColor: style.ink, placeholderColor: style.muted,
                                            fontSize: 12, focusRequest: searchFocusRequest, onFocusChange: searchFocusChanged)
                    .frame(height: 20)
            }
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
            ClipboardBrowserFooter(hasSelection: selected != nil, count: results.count, focus: inputFocus,
                                   hasQuery: !browser.query.isEmpty, isPreviewing: isPreviewing, togglePreview: togglePreview,
                                   copy: { if let selected { onCopyAndClose(selected.content) } },
                                   unseenCaptureCount: browser.unseenCaptureCount, jumpToLatest: summon)
        }
        .clipboardShortcutHelp(isPresented: browser.transientLayer == .help, close: closeHelp)
        .modifier(ClipboardBrowserHistoryControls(isConfirming: browser.transientLayer == .confirmation,
                                                  dismissConfirmation: dismissConfirmation, historyChanged: refreshTagLookup))
        .background { ClipboardBrowserKeyboard(focus: contentFocus, action: handleKey) }
        .environment(\.clipboardBrowserStyle, style)
        .background(style.surface)
        .frame(width: ClipboardBrowserStyle.popoverSize.width, height: ClipboardBrowserStyle.popoverSize.height)
        .background {
            ClipboardPopupPresence { visible in
                isVisible = visible
                if visible { summon() }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onReceive(monitor.captures) {
            if isVisible { browser.noteCapture() }
        }
        .onChange(of: browserItems) { _, snapshots in
            let selectedID = browser.selectedID
            let focus = browser.focus
            browser.replaceItems(snapshots)
            if selectedID != browser.selectedID { revealRequest = UUID() }
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

    private var titleBar: some View {
        ClipboardBrowserTitleBar(title: "clipass") {
            Button(action: openSettingsAndActivate) {
                ClipboardBrowserIcon(symbol: "wand.and.stars", count: rules.count)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Transform Rules")
            .help("Transform Rules")

            Button(action: openSettingsAndActivate) {
                ClipboardBrowserIcon(symbol: "bolt", count: hooks.count)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Automation Hooks")
            .help("Automation Hooks")

            ClipboardBrowserOverflow(canClear: items.contains { !$0.isPinned }, confirmClear: confirmClear) {
                Button("Settings", action: openSettingsAndActivate)
                    .keyboardShortcut(",", modifiers: .command)
                Button("Quit clipass") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
                Divider()
            }
        }
        .foregroundStyle(style.muted)
    }

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
                        HistoryItemRow(
                            item: item,
                            previewText: previewText(for: item),
                            tagInfos: tagLookup.tagsByItem[item.id] ?? [],
                            allTags: allTags,
                            customActions: customActions,
                            onDelete: { deleteItem(item) },
                            onTogglePin: { togglePin(item) },
                            onTagChanged: refreshTagLookup,
                            isSelected: browser.selectedID == item.id,
                            onSelect: {
                                browser.selectItem(item.id)
                                browser.setFocus(.list)
                                applyBrowserFocus()
                            },
                            onPreview: togglePreview
                        )
                        .overlay(alignment: .bottom) {
                            style.rowSeparator(below: index, in: results, selectedID: browser.selectedID)
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
                if let id = browser.selectedID { proxy.scrollTo(id, anchor: .top) }
            }
            .onChange(of: revealRequest) { _, _ in
                if let id = browser.selectedID { proxy.scrollTo(id, anchor: .top) }
            }
        }
    }

    private func openSettingsAndActivate() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "settings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        try? modelContext.save()
    }

    private func deleteItem(_ item: ClipboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func confirmClear() {
        browser.showLayer(.confirmation)
        focusedArea = nil
        searchFocusRequest = .init(intent: .resign)
    }

    private func dismissConfirmation() { _ = handleKey(.back, focus: .control) }
}
