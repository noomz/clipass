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
        }
        .frame(width: 500, height: 400)
    }
}
