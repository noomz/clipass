import SwiftUI
import SwiftData

struct RedactionPatternEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let pattern: RedactionPattern?  // nil for new, existing for edit
    
    @State private var name = ""
    @State private var patternText = ""
    @State private var category = RedactionPattern.categoryCustom
    @State private var isEnabled = true
    @State private var testInput = ""
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
    
    private var testResult: String? {
        guard !testInput.isEmpty, !patternText.isEmpty, isPatternValid else { return nil }
        
        // Create a temporary pattern to test redaction
        let tempPattern = RedactionPattern(
            name: name,
            pattern: patternText,
            category: category,
            isEnabled: true,
            isBuiltIn: false
        )
        
        return DisplayFormatter.redact(testInput, patterns: [tempPattern])
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(isEditing ? "Edit Redaction Pattern" : "Add Redaction Pattern")
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
                        TextField("e.g., secret_[a-zA-Z0-9]+", text: $patternText)
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
                    
                    // Category picker (read-only for custom patterns)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(RedactionPattern.categoryCustom)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundColor(.secondary)
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
                        
                        if let result = testResult {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Result:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                let hasRedaction = result != testInput
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: hasRedaction ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(hasRedaction ? .orange : .green)
                                        Text(hasRedaction ? "Content would be redacted" : "No match - content unchanged")
                                            .font(.body)
                                            .foregroundColor(hasRedaction ? .orange : .green)
                                    }
                                    
                                    if hasRedaction {
                                        Text(result)
                                            .font(.caption)
                                            .fontDesign(.monospaced)
                                            .foregroundColor(.secondary)
                                    }
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
        .frame(width: 320, height: 450)
        .onAppear {
            if let pattern = pattern {
                name = pattern.name
                patternText = pattern.pattern
                category = pattern.category
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
        } else {
            // Create new pattern
            let newPattern = RedactionPattern(
                name: name,
                pattern: patternText,
                category: RedactionPattern.categoryCustom,
                isEnabled: isEnabled,
                isBuiltIn: false
            )
            modelContext.insert(newPattern)
        }
        
        // Invalidate cache since patterns changed
        DisplayFormatter.invalidateCache()
        
        dismiss()
    }
}
