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

    private func previewText(for item: ClipboardItem) -> String {
        if let cached = previewCache[item.id] { return cached }
        let text = DisplayFormatter.format(item.content, maxLength: previewMaxLength, patterns: redactionPatterns)
        previewCache[item.id] = text
        return text
    }

    var body: some View {
        let _ = perfLog("body eval: items=\(items.count), display=\(displayItems.count), search='\(browser.query)'")
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clipboard History")
                    .font(.headline)
                Spacer()

                Button {
                    openSettingsAndActivate()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "wand.and.stars")
                        if !rules.isEmpty {
                            Text("\(rules.count)")
                                .font(.caption2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Transform Rules")

                Button {
                    openSettingsAndActivate()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt")
                        if !hooks.isEmpty {
                            Text("\(hooks.count)")
                                .font(.caption2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Automation Hooks")
            }
            .padding()

            ClipboardBrowserTabs(tab: browser.tab, onSelect: openTab)

            TextField("Search text or tag:work", text: searchText)
                .textFieldStyle(.roundedBorder)
                .focused($focusedArea, equals: .search)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            if let emptyState = browser.emptyState {
                ClipboardBrowserEmptyView(state: emptyState) {
                    searchText.wrappedValue = ""
                    focusedArea = .search
                }
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(displayItems) { item in
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
                            .id(item.id)
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        }
                    }
                    .listStyle(.plain)
                    .focused($focusedArea, equals: .list)
                    .onAppear {
                        if let id = browser.selectedID { proxy.scrollTo(id) }
                    }
                    .onChange(of: revealRequest) { _, _ in
                        if let id = browser.selectedID {
                            proxy.scrollTo(id)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Copy") {
                    if let item = browser.selectedItem { onCopy(item.content) }
                }
                .disabled(browser.selectedItem == nil)

                if !items.isEmpty {
                    Button("Clear All") {
                        clearAllItems()
                    }
                    .foregroundColor(.red)
                }
                Spacer()
                Button {
                    openSettingsAndActivate()
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .help("Settings")
                .keyboardShortcut(",", modifiers: .command)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding()
        }
        .frame(width: 300, height: 350)
        .onAppear {
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
