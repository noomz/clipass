import SwiftUI
import SwiftData

struct HookEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let hook: Hook?

    @State private var name: String = ""
    @State private var pattern: String = ""
    @State private var command: String = ""
    @State private var sourceAppFilter: String = ""
    @State private var isEnabled: Bool = true
    @State private var order: Int = 0

    @State private var patternError: String?

    private var isEditing: Bool {
        hook != nil
    }

    private var isPatternValid: Bool {
        guard !pattern.isEmpty else { return true } // Empty pattern is valid (matches all)

        do {
            _ = try Regex(pattern)
            return true
        } catch {
            return false
        }
    }

    private var canSave: Bool {
        !name.isEmpty && !command.isEmpty && isPatternValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isEditing ? "Edit Hook" : "Add Hook")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveHook()
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
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
                        TextField("Hook name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Pattern field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pattern (Regex, optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Leave empty to match all", text: $pattern)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                            .onChange(of: pattern) { _, newValue in
                                validatePattern(newValue)
                            }

                        if let error = patternError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else if pattern.isEmpty {
                            Text("Empty pattern matches all clipboard content")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Command field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., /path/to/script.sh", text: $command)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                        Text("Receives CLIPASS_CONTENT and CLIPASS_SOURCE_APP environment variables")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Source App Filter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source App (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., com.apple.Terminal", text: $sourceAppFilter)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                        Text("Leave empty to apply to all apps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Order field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Priority Order")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("Order", value: $order, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("Lower runs first")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Enabled toggle
                    Toggle("Enabled", isOn: $isEnabled)
                        .toggleStyle(.switch)
                }
                .padding()
            }
        }
        .frame(width: 320, height: 400)
        .onAppear {
            if let hook = hook {
                name = hook.name
                pattern = hook.pattern
                command = hook.command
                sourceAppFilter = hook.sourceAppFilter ?? ""
                isEnabled = hook.isEnabled
                order = hook.order
            }
        }
    }

    private func validatePattern(_ pattern: String) {
        guard !pattern.isEmpty else {
            patternError = nil
            return
        }

        do {
            _ = try Regex(pattern)
            patternError = nil
        } catch {
            patternError = "Invalid regex: \(error.localizedDescription)"
        }
    }

    private func saveHook() {
        if let existingHook = hook {
            // Update existing hook
            existingHook.name = name
            existingHook.pattern = pattern
            existingHook.command = command
            existingHook.sourceAppFilter = sourceAppFilter.isEmpty ? nil : sourceAppFilter
            existingHook.isEnabled = isEnabled
            existingHook.order = order
        } else {
            // Create new hook
            let newHook = Hook(
                name: name,
                pattern: pattern,
                command: command,
                sourceAppFilter: sourceAppFilter.isEmpty ? nil : sourceAppFilter,
                isEnabled: isEnabled,
                order: order
            )
            modelContext.insert(newHook)
        }

        dismiss()
    }
}
