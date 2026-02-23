import SwiftUI
import SwiftData

struct ContextActionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let action: ContextAction?

    @State private var name: String = ""
    @State private var command: String = ""
    @State private var contentFilter: String = ""
    @State private var replacesClipboard: Bool = false
    @State private var showNotification: Bool = true
    @State private var isEnabled: Bool = true
    @State private var order: Int = 0

    @State private var filterError: String?

    private var isEditing: Bool {
        action != nil
    }

    private var isFilterValid: Bool {
        guard !contentFilter.isEmpty else { return true }
        do {
            _ = try Regex(contentFilter)
            return true
        } catch {
            return false
        }
    }

    private var canSave: Bool {
        !name.isEmpty && !command.isEmpty && isFilterValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isEditing ? "Edit Action" : "Add Action")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveAction()
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
                        TextField("Action name (shown in menu)", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Command field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., pbpaste | tr '[:lower:]' '[:upper:]'", text: $command)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                        Text("CLIPASS_CONTENT env var contains the item text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Content filter field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Content Filter (Regex, optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Leave empty to always show", text: $contentFilter)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                            .onChange(of: contentFilter) { _, newValue in
                                validateFilter(newValue)
                            }

                        if let error = filterError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else if contentFilter.isEmpty {
                            Text("Empty filter means this action shows for all items")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Action only shows when content matches this pattern")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Replace clipboard toggle
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Replace clipboard with output", isOn: $replacesClipboard)
                            .toggleStyle(.switch)
                        Text("When enabled, command stdout replaces the clipboard content")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Show notification toggle
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Show notification on success", isOn: $showNotification)
                            .toggleStyle(.switch)
                        Text("When enabled, shows a macOS notification with the action result")
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
                            Text("Lower appears first")
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
        .frame(width: 360, height: 440)
        .onAppear {
            if let action = action {
                name = action.name
                command = action.command
                contentFilter = action.contentFilter
                replacesClipboard = action.replacesClipboard
                showNotification = action.showNotification
                isEnabled = action.isEnabled
                order = action.order
            }
        }
    }

    private func validateFilter(_ filter: String) {
        guard !filter.isEmpty else {
            filterError = nil
            return
        }

        do {
            _ = try Regex(filter)
            filterError = nil
        } catch {
            filterError = "Invalid regex: \(error.localizedDescription)"
        }
    }

    private func saveAction() {
        if let existingAction = action {
            existingAction.name = name
            existingAction.command = command
            existingAction.contentFilter = contentFilter
            existingAction.replacesClipboard = replacesClipboard
            existingAction.showNotification = showNotification
            existingAction.isEnabled = isEnabled
            existingAction.order = order
        } else {
            let newAction = ContextAction(
                name: name,
                command: command,
                contentFilter: contentFilter,
                replacesClipboard: replacesClipboard,
                showNotification: showNotification,
                isEnabled: isEnabled,
                order: order
            )
            modelContext.insert(newAction)
        }

        dismiss()
    }
}
