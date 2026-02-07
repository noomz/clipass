import SwiftUI
import SwiftData

struct DisplaySettingsView: View {
    @AppStorage("previewMaxLength") private var previewMaxLength = 80
    @State private var previewText = "This is a sample preview text with john@example.com and sk-xxxx-REDACTED for testing redaction patterns."
    @State private var selectedPatternType = 0  // 0 = Built-in, 1 = Custom
    
    // Query redaction patterns for live preview
    @Query private var redactionPatterns: [RedactionPattern]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Preview Length Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview Length")
                            .font(.headline)
                        
                        HStack {
                            Text("Characters to show:")
                                .foregroundColor(.secondary)
                            
                            TextField("", value: $previewMaxLength, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: previewMaxLength) { _, newValue in
                                    // Clamp to valid range
                                    previewMaxLength = min(200, max(20, newValue))
                                }
                            
                            Stepper("", value: $previewMaxLength, in: 20...200, step: 10)
                                .labelsHidden()
                        }
                        
                        Text("Truncates at word boundary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    
                    // MARK: - Redaction Patterns Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Redaction Patterns")
                            .font(.headline)
                        
                        Picker("", selection: $selectedPatternType) {
                            Text("Built-in").tag(0)
                            Text("Custom").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedPatternType == 0 {
                            RedactionPatternsView(showBuiltIn: true)
                                .frame(minHeight: 120, maxHeight: 160)
                        } else {
                            RedactionPatternsView(showBuiltIn: false)
                                .frame(minHeight: 120, maxHeight: 160)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    
                    // MARK: - Live Preview Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Live Preview")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sample text:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter sample text to test...", text: $previewText)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Formatted result:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(formattedPreview.count)/\(previewMaxLength) chars")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(formattedPreview)
                                .font(.body)
                                .fontDesign(.monospaced)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedPreview: String {
        DisplayFormatter.format(previewText, maxLength: previewMaxLength, patterns: redactionPatterns)
    }
}
