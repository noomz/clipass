import SwiftUI
import SwiftData

struct RedactionPatternsView: View {
    let showBuiltIn: Bool  // true = show isBuiltIn patterns, false = show custom
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allPatterns: [RedactionPattern]
    @State private var showingEditor = false
    @State private var editingPattern: RedactionPattern?
    
    // Filtered patterns based on showBuiltIn flag
    private var patterns: [RedactionPattern] {
        allPatterns.filter { $0.isBuiltIn == showBuiltIn }
    }
    
    // Group patterns by category for built-in view
    private var groupedPatterns: [String: [RedactionPattern]] {
        Dictionary(grouping: patterns) { $0.category }
    }
    
    // Category order for display
    private let categoryOrder = [
        RedactionPattern.categoryCredentials,
        RedactionPattern.categoryFinancial,
        RedactionPattern.categoryPII
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showBuiltIn {
                builtInPatternsView
            } else {
                customPatternsView
            }
        }
        .sheet(isPresented: $showingEditor) {
            RedactionPatternEditorView(pattern: nil)
        }
        .sheet(item: $editingPattern) { pattern in
            RedactionPatternEditorView(pattern: pattern)
        }
    }
    
    // MARK: - Built-in Patterns View
    
    private var builtInPatternsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(categoryOrder, id: \.self) { category in
                    if let patternsInCategory = groupedPatterns[category], !patternsInCategory.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                            
                            ForEach(patternsInCategory) { pattern in
                                RedactionPatternRow(
                                    pattern: pattern,
                                    showCategory: false,
                                    canDelete: false,
                                    onEdit: { },
                                    onDelete: { }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Custom Patterns View
    
    private var customPatternsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(action: { showingEditor = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            if patterns.isEmpty {
                VStack {
                    Spacer()
                    Text("No custom patterns")
                        .foregroundColor(.secondary)
                    Text("Add patterns to redact custom content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(patterns) { pattern in
                            RedactionPatternRow(
                                pattern: pattern,
                                showCategory: true,
                                canDelete: true,
                                onEdit: { editingPattern = pattern },
                                onDelete: { deletePattern(pattern) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func deletePattern(_ pattern: RedactionPattern) {
        modelContext.delete(pattern)
        DisplayFormatter.invalidateCache()
    }
}

// MARK: - Pattern Row

struct RedactionPatternRow: View {
    @Bindable var pattern: RedactionPattern
    let showCategory: Bool
    let canDelete: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: canDelete ? onEdit : {}) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(pattern.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if showCategory {
                            Text(pattern.category)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(pattern.pattern)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Toggle("", isOn: $pattern.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: pattern.isEnabled) { _, _ in
                        DisplayFormatter.invalidateCache()
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            if canDelete {
                Button("Edit") {
                    onEdit()
                }
                Divider()
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
    }
}
