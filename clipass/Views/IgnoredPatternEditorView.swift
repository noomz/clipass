import SwiftUI
import SwiftData

struct IgnoredPatternEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let pattern: IgnoredPattern?

    @State private var name: String = ""
    @State private var patternText: String = ""
    @State private var isEnabled: Bool = true
    @State private var testInput: String = ""
    @State private var patternError: String?

    private var isEditing: Bool {
        pattern != nil
    }

    private var isPatternValid: Bool {
        guard !patternText.isEmpty else { return true }

        do {
            _ = try Regex(patternText)
            return true
        } catch {
            return false
        }
    }

    private var testMatches: Bool {
        guard !testInput.isEmpty, !patternText.isEmpty, isPatternValid else { return false }

        do {
            let regex = try Regex(patternText)
            return testInput.contains(regex)
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

                Text(isEditing ? "Edit Ignore Pattern" : "Add Ignore Pattern")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    savePattern()
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty || patternText.isEmpty || !isPatternValid)
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
                        TextField("Pattern name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Pattern field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pattern (Regex)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., ^password:", text: $patternText)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                            .onChange(of: patternText) { _, newValue in
                                validatePattern(newValue)
                            }

                        if let error = patternError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
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

                        if !testInput.isEmpty && !patternText.isEmpty && isPatternValid {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Result:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Image(systemName: testMatches ? "xmark.circle.fill" : "checkmark.circle.fill")
                                        .foregroundColor(testMatches ? .red : .green)
                                    Text(testMatches ? "Would be ignored" : "Would be stored")
                                        .font(.body)
                                        .foregroundColor(testMatches ? .red : .green)
                                }
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
        .frame(width: 320, height: 400)
        .onAppear {
            if let pattern = pattern {
                name = pattern.name
                patternText = pattern.pattern
                isEnabled = pattern.isEnabled
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

    private func savePattern() {
        if let existingPattern = pattern {
            // Update existing pattern
            existingPattern.name = name
            existingPattern.pattern = patternText
            existingPattern.isEnabled = isEnabled
            // Invalidate cache since pattern was modified
            AppServices.shared.clipboardMonitor.invalidatePatternCache()
        } else {
            // Create new pattern
            let newPattern = IgnoredPattern(
                name: name,
                pattern: patternText,
                isEnabled: isEnabled
            )
            modelContext.insert(newPattern)
        }

        dismiss()
    }
}
