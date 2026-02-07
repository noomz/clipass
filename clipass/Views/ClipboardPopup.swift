import SwiftUI
import SwiftData
import AppKit
import KeyboardShortcuts

struct ClipboardPopup: View {
    var monitor: ClipboardMonitor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @Query private var rules: [TransformRule]
    @Query private var hooks: [Hook]
    @Query private var redactionPatterns: [RedactionPattern]
    @State private var searchText = ""

    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
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

            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

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
            } else if filteredItems.isEmpty {
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredItems) { item in
                            HistoryItemRow(item: item, redactionPatterns: redactionPatterns) {
                                deleteItem(item)
                            }
                        }
                    }
                }
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
    }

    private func openSettingsAndActivate() {
        // Temporarily set activation policy to regular to allow keyboard focus
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "settings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
        }
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
