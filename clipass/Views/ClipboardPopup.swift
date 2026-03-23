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

// MARK: - Isolated search field
// Owns its own @State for the raw text so keystrokes only re-render this tiny view.
// Reports debounced value to parent via binding — parent body only re-evals on actual filter change.
private struct PopupSearchField: View {
    @Binding var debouncedText: String
    @State private var rawText = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        TextField("Search...", text: $rawText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .onChange(of: rawText) { _, newValue in
                debounceTask?.cancel()
                if newValue.isEmpty {
                    debouncedText = ""
                } else {
                    debounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        debouncedText = newValue
                    }
                }
            }
    }
}

struct ClipboardPopup: View {
    var monitor: ClipboardMonitor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ClipboardItem.timestamp, order: .reverse)
    private var items: [ClipboardItem]
    @Query private var rules: [TransformRule]
    @Query private var hooks: [Hook]
    @Query private var redactionPatterns: [RedactionPattern]
    @Query(sort: \ContextAction.order) private var customActions: [ContextAction]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var searchText = ""  // Only updated by debounced output

    // Cached data — rebuilt on specific triggers
    @State private var sortedItems: [ClipboardItem] = []
    @State private var displayItems: [ClipboardItem] = []
    @State private var tagLookup: TagLookup = .empty
    @State private var previewCache: [UUID: String] = [:]

    @AppStorage("previewMaxLength") private var previewMaxLength = 80

    private func rebuildSorted() {
        sortedItems = items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.timestamp > b.timestamp
        }
    }

    private func rebuildDisplay(search: String) {
        guard !search.isEmpty else {
            displayItems = sortedItems
            return
        }
        displayItems = sortedItems.filter { $0.content.localizedCaseInsensitiveContains(search) }
    }

    private func refreshTagLookup() {
        tagLookup = TagLookup.build(from: modelContext)
    }

    private func previewText(for item: ClipboardItem) -> String {
        if let cached = previewCache[item.id] { return cached }
        let text = DisplayFormatter.format(item.content, maxLength: previewMaxLength, patterns: redactionPatterns)
        previewCache[item.id] = text
        return text
    }

    var body: some View {
        let _ = perfLog("body eval: items=\(items.count), display=\(displayItems.count), search='\(searchText)'")
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

            PopupSearchField(debouncedText: $searchText)

            Divider()

            if items.isEmpty {
                VStack {
                    Spacer()
                    Text("No items yet")
                        .foregroundColor(.secondary)
                    Text("Copy some text to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if displayItems.isEmpty && !searchText.isEmpty {
                VStack {
                    Spacer()
                    Text("No results")
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
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
                            onTagChanged: {
                                refreshTagLookup()
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            HStack {
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
            rebuildSorted()
            rebuildDisplay(search: "")
        }
        .onChange(of: items) { _, _ in
            perfLog("onChange(items) fired")
            previewCache = [:]
            rebuildSorted()
            rebuildDisplay(search: searchText)
        }
        // Only fires when debounced value arrives — not on every keystroke
        .onChange(of: searchText) { _, newValue in
            perfLog("onChange(searchText) = '\(newValue)'")
            rebuildDisplay(search: newValue)
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
