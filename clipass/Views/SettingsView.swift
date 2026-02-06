import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            RulesView()
                .tabItem {
                    Label("Rules", systemImage: "wand.and.stars")
                }

            HooksView()
                .tabItem {
                    Label("Hooks", systemImage: "bolt")
                }

            IgnoredAppsView()
                .tabItem {
                    Label("Ignored Apps", systemImage: "xmark.app")
                }

            IgnoredPatternsView()
                .tabItem {
                    Label("Ignore Patterns", systemImage: "slash.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}
