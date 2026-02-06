import SwiftUI
import SwiftData

struct IgnoredPatternsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IgnoredPattern.createdAt) private var ignoredPatterns: [IgnoredPattern]
    @State private var showAddSheet = false
    @State private var editingPattern: IgnoredPattern?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ignore Patterns")
                    .font(.headline)

                Spacer()

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if ignoredPatterns.isEmpty {
                VStack {
                    Spacer()
                    Text("No ignore patterns")
                        .foregroundColor(.secondary)
                    Text("Add patterns to skip storing matching content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(ignoredPatterns) { pattern in
                            IgnoredPatternRow(pattern: pattern) {
                                editingPattern = pattern
                            } onDelete: {
                                deletePattern(pattern)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            IgnoredPatternEditorView(pattern: nil)
        }
        .sheet(item: $editingPattern) { pattern in
            IgnoredPatternEditorView(pattern: pattern)
        }
    }

    private func deletePattern(_ pattern: IgnoredPattern) {
        modelContext.delete(pattern)
    }
}

struct IgnoredPatternRow: View {
    @Bindable var pattern: IgnoredPattern
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.name)
                        .font(.body)
                        .foregroundColor(.primary)

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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
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
