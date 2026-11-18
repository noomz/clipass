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
    var onCopy: (String) -> Void = { content in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
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
    @State private var revealRequest = UUID()
    @State private var scrollAnchor: UUID?
    @State private var isVisible = false
    @State private var tagLookup: TagLookup = .empty
    @State private var previewCache: [UUID: String] = [:]

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
        focusedArea = browser.focus
        revealRequest = UUID()
    }

    private func refreshTagLookup() {
        tagLookup = TagLookup.build(from: modelContext)
        browser.replaceItems(browserItems)
    }

    private func summon() {
        tagLookup = TagLookup.build(from: modelContext)
        browser.summon(items: browserItems)
        focusedArea = .search
        scrollAnchor = browser.selectedID
        revealRequest = UUID()
    }

    private func previewText(for item: ClipboardItem) -> String {
        if let cached = previewCache[item.id] { return cached }
        let text = DisplayFormatter.format(item.content, maxLength: previewMaxLength, patterns: redactionPatterns)
        previewCache[item.id] = text
        return text
    }

    private var style: ClipboardBrowserStyle { ClipboardBrowserStyle(compact: true, scheme: colorScheme) }

    var body: some View {
        let results = displayItems
        let selected = browser.selectedItem
        let _ = perfLog("body eval: items=\(items.count), display=\(results.count), search='\(browser.query)'")
        VStack(spacing: 0) {
            titleBar
            ClipboardBrowserSearch(query: browser.query, focused: focusedArea == .search, onClear: clearSearch) {
                TextField("Text or tag:work", text: searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(style.ink)
                    .accessibilityLabel("Search clipboard")
                    .focused($focusedArea, equals: .search)
            }
            ClipboardBrowserTabs(tab: browser.tab, recentCount: items.count,
                                 pinnedCount: items.filter(\.isPinned).count, onSelect: openTab)
            ClipboardBrowserSection(tab: browser.tab, isSearching: !browser.query.isEmpty, count: results.count)
            if let emptyState = browser.emptyState {
                ClipboardBrowserEmptyView(state: emptyState, query: browser.query, clearSearch: clearSearch)
            } else {
                historyList(results)
            }
            ClipboardBrowserFooter(hasSelection: selected != nil, count: results.count, focus: browser.focus,
                                   copy: { if let selected { onCopy(selected.content) } },
                                   unseenCaptureCount: browser.unseenCaptureCount, jumpToLatest: summon)
        }
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
            previewCache = [:]
            browser.replaceItems(snapshots)
        }
        .onChange(of: focusedArea) { _, focus in
            if let focus { browser.setFocus(focus) }
        }
    }

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

            Menu {
                Button("Settings", action: openSettingsAndActivate)
                    .keyboardShortcut(",", modifiers: .command)
                if !items.isEmpty {
                    Button("Clear All", role: .destructive, action: clearAllItems)
                }
                Divider()
                Button("Quit clipass") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            } label: {
                ClipboardBrowserIcon(symbol: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More actions")
        }
        .foregroundStyle(style.muted)
    }

    private func clearSearch() {
        searchText.wrappedValue = ""
        focusedArea = .search
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
                            redactionPatterns: redactionPatterns,
                            customActions: customActions,
                            onDelete: { deleteItem(item) },
                            onTogglePin: { togglePin(item) },
                            onTagChanged: refreshTagLookup,
                            isSelected: browser.selectedID == item.id,
                            onSelect: {
                                browser.selectItem(item.id)
                                browser.setFocus(.list)
                                focusedArea = .list
                            }
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
    }

    private func clearAllItems() {
        for item in items {
            modelContext.delete(item)
        }
    }
}
