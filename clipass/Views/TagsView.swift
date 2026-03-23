import SwiftUI
import SwiftData

// MARK: - TagsView (Settings Tab Root)

/// Settings Tags tab: list + editor split pane.
/// Left pane: 180pt wide tag list with [+][-] toolbar.
/// Right pane: TagEditorPane or empty-state prompt.
struct TagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var selectedTag: Tag?
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            // Left pane — tag list
            VStack(spacing: 0) {
                if tags.isEmpty {
                    // Empty state
                    VStack(spacing: 6) {
                        Spacer()
                        Text("No tags yet")
                            .foregroundColor(.secondary)
                        Text("Right-click any clipboard item to add tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                } else {
                    List(tags, id: \.id, selection: $selectedTag) { tag in
                        TagListRow(tag: tag)
                            .tag(tag)
                    }
                    .listStyle(.sidebar)
                }

                Divider()

                // Toolbar [+] [-]
                HStack(spacing: 0) {
                    Button(action: addTag) {
                        Image(systemName: "plus")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add tag")

                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "minus")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedTag == nil)
                    .accessibilityLabel("Remove selected tag")

                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(width: 180)

            Divider()

            // Right pane — editor or placeholder
            if let tag = selectedTag {
                TagEditorPane(tag: tag, onDelete: { showDeleteConfirmation = true })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack {
                    Text("Select a tag to edit")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Delete tag '\(selectedTag?.name ?? "")'?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let tag = selectedTag {
                    deleteTag(tag)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Actions

    private func addTag() {
        let newTag = Tag(name: "New Tag", colorHex: Tag.randomPresetColor())
        modelContext.insert(newTag)
        try? modelContext.save()
        selectedTag = newTag
    }

    private func deleteTag(_ tag: Tag) {
        selectedTag = nil  // Clear selection BEFORE delete to prevent dangling binding
        modelContext.delete(tag)
        try? modelContext.save()
    }
}

// MARK: - TagListRow

/// Row in the Settings tag list: colored dot + tag name.
struct TagListRow: View {
    let tag: Tag

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 10, height: 10)
            Text(tag.name)
                .font(.body)
        }
    }
}

// MARK: - TagEditorPane

/// Right-pane editor for a selected tag: name field, color palette, delete button.
/// Uses local state to avoid SwiftData crashes from live @Bindable bindings during saves.
struct TagEditorPane: View {
    let tag: Tag
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var editName: String = ""
    @State private var editColorHex: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                    .onChange(of: editName) { _, newValue in
                        save()
                    }
            }

            // Color palette
            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TagColorPalette(selectedHex: $editColorHex)
                    .onChange(of: editColorHex) { _, newValue in
                        save()
                    }
            }

            Spacer()

            // Delete button
            Button("Delete Tag", role: .destructive) {
                onDelete()
            }
        }
        .padding(16)
        .onAppear { loadFromTag() }
        .onChange(of: tag.id) { _, _ in loadFromTag() }
    }

    private func loadFromTag() {
        editName = tag.name
        editColorHex = tag.colorHex
    }

    private func save() {
        tag.name = editName
        tag.colorHex = editColorHex
        try? modelContext.save()
    }
}

// MARK: - TagColorPalette

/// 8-swatch horizontal color picker using Tag.presetColors.
/// Selected swatch shows a white checkmark overlay.
struct TagColorPalette: View {
    @Binding var selectedHex: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Tag.presetColors, id: \.self) { color in
                Button(action: { selectedHex = color }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 22, height: 22)
                        if selectedHex == color {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
