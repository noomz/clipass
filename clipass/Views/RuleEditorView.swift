import SwiftUI
import SwiftData

struct RuleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let rule: TransformRule?

    @State private var name: String = ""
    @State private var pattern: String = ""
    @State private var replacement: String = ""
    @State private var sourceAppFilter: String = ""
    @State private var isEnabled: Bool = true
    @State private var order: Int = 50

    @State private var testInput: String = ""
    @State private var patternError: String?

    private var isEditing: Bool {
        rule != nil
    }

    private var testOutput: String {
        guard !testInput.isEmpty, !pattern.isEmpty else { return "" }

        do {
            let regex = try Regex(pattern)
            return testInput.replacing(regex, with: replacement)
        } catch {
            return testInput
        }
    }

    private var isPatternValid: Bool {
        guard !pattern.isEmpty else { return true }

        do {
            _ = try Regex(pattern)
            return true
        } catch {
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isEditing ? "Edit Rule" : "Add Rule")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveRule()
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty || pattern.isEmpty || !isPatternValid)
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
                        TextField("Rule name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Pattern field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pattern (Regex)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., \\s+$", text: $pattern)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                            .onChange(of: pattern) { _, newValue in
                                validatePattern(newValue)
                            }

                        if let error = patternError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }

                    // Replacement field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Replacement")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Leave empty to delete matches", text: $replacement)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
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

                    Divider()

                    // Test section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Test Pattern")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Enter test text...", text: $testInput)
                            .textFieldStyle(.roundedBorder)

                        if !testInput.isEmpty && !pattern.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Result:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(testOutput.isEmpty ? "(empty)" : testOutput)
                                    .font(.body)
                                    .fontDesign(.monospaced)
                                    .foregroundColor(testOutput != testInput ? .green : .primary)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 320, height: 450)
        .onAppear {
            if let rule = rule {
                name = rule.name
                pattern = rule.pattern
                replacement = rule.replacement
                sourceAppFilter = rule.sourceAppFilter ?? ""
                isEnabled = rule.isEnabled
                order = rule.order
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

    private func saveRule() {
        if let existingRule = rule {
            // Update existing rule
            existingRule.name = name
            existingRule.pattern = pattern
            existingRule.replacement = replacement
            existingRule.sourceAppFilter = sourceAppFilter.isEmpty ? nil : sourceAppFilter
            existingRule.isEnabled = isEnabled
            existingRule.order = order
        } else {
            // Create new rule
            let newRule = TransformRule(
                name: name,
                pattern: pattern,
                replacement: replacement,
                sourceAppFilter: sourceAppFilter.isEmpty ? nil : sourceAppFilter,
                isEnabled: isEnabled,
                order: order
            )
            modelContext.insert(newRule)
        }

        dismiss()
    }
}
