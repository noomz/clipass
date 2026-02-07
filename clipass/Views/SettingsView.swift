import SwiftUI
import SwiftData

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

// MARK: - General Settings (placeholder for Phase 8)

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("General settings coming soon...")
                    .foregroundColor(.secondary)
            } header: {
                Text("App Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
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
