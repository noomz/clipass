import SwiftUI
import SwiftData

struct IgnoredAppEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let app: IgnoredApp?

    @State private var name: String = ""
    @State private var bundleId: String = ""
    @State private var isEnabled: Bool = true

    private var isEditing: Bool {
        app != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isEditing ? "Edit Ignored App" : "Add Ignored App")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveApp()
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty || bundleId.isEmpty)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("App name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Bundle ID field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bundle ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., com.1password.1password", text: $bundleId)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                        Text("e.g., com.1password.1password")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Enabled toggle
                    Toggle("Enabled", isOn: $isEnabled)
                        .toggleStyle(.switch)
                }
                .padding()
            }
        }
        .frame(width: 320, height: 250)
        .onAppear {
            if let app = app {
                name = app.name
                bundleId = app.bundleId
                isEnabled = app.isEnabled
            }
        }
    }

    private func saveApp() {
        if let existingApp = app {
            // Update existing app
            existingApp.name = name
            existingApp.bundleId = bundleId
            existingApp.isEnabled = isEnabled
        } else {
            // Create new app
            let newApp = IgnoredApp(
                bundleId: bundleId,
                name: name,
                isEnabled: isEnabled
            )
            modelContext.insert(newApp)
        }

        dismiss()
    }
}
