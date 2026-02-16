import SwiftUI
import SwiftData
import LaunchAtLogin
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            RulesView()
                .tabItem {
                    Label("Transforms", systemImage: "wand.and.stars")
                }

            HooksView()
                .tabItem {
                    Label("Automation", systemImage: "bolt")
                }

            FilteringSettingsView()
                .tabItem {
                    Label("Filtering", systemImage: "line.3.horizontal.decrease.circle")
                }

            DisplaySettingsView()
                .tabItem {
                    Label("Display", systemImage: "text.alignleft")
                }
        }
        .frame(width: 500, height: 400)
        .onDisappear {
            // Reset to accessory (menu bar only) when settings closes
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 100
    @AppStorage("autoCleanupDays") private var autoCleanupDays = 0
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            // BEHV-01: Launch at Login
            Section {
                LaunchAtLogin.Toggle()
            } header: {
                Text("Startup")
            }

            // BEHV-02: Max history items
            Section {
                Stepper("Maximum items: \(maxHistoryItems)",
                        value: $maxHistoryItems,
                        in: 10...1000,
                        step: 10)
                    .onChange(of: maxHistoryItems) { _, newValue in
                        pruneToLimit(newValue)
                    }
            } header: {
                Text("History")
            }

            // BEHV-03: Global hotkey customization
            Section {
                KeyboardShortcuts.Recorder("Toggle Clipboard:", name: .toggleClipboard)
            } header: {
                Text("Hotkey")
            }

            // BEHV-04: Auto-cleanup age
            Section {
                Picker("Auto-delete items older than:", selection: $autoCleanupDays) {
                    Text("Never").tag(0)
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
            } header: {
                Text("Cleanup")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func pruneToLimit(_ limit: Int) {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let allItems = try? modelContext.fetch(descriptor) else { return }
        if allItems.count > limit {
            for item in allItems.suffix(from: limit) {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Filtering Settings (combines Ignored Apps + Patterns)

struct FilteringSettingsView: View {
    @State private var selectedSection = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Section picker
            Picker("", selection: $selectedSection) {
                Text("Ignored Apps").tag(0)
                Text("Ignore Patterns").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content
            if selectedSection == 0 {
                IgnoredAppsView()
            } else {
                IgnoredPatternsView()
            }
        }
    }
}
