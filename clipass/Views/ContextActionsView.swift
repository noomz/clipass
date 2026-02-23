import SwiftUI
import SwiftData

struct ContextActionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ContextAction.order) private var actions: [ContextAction]
    @State private var showAddSheet = false
    @State private var editingAction: ContextAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Custom Actions")
                    .font(.headline)

                Spacer()

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if actions.isEmpty {
                VStack {
                    Spacer()
                    Text("No custom actions yet")
                        .foregroundColor(.secondary)
                    Text("Add actions that appear in the right-click menu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(actions) { action in
                            ContextActionRow(action: action) {
                                editingAction = action
                            } onDelete: {
                                deleteAction(action)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ContextActionEditorView(action: nil)
        }
        .sheet(item: $editingAction) { action in
            ContextActionEditorView(action: action)
        }
    }

    private func deleteAction(_ action: ContextAction) {
        modelContext.delete(action)
    }
}

struct ContextActionRow: View {
    @Bindable var action: ContextAction
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(action.name)
                            .font(.body)
                            .foregroundColor(.primary)

                        if action.replacesClipboard {
                            Text("replaces")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.7))
                                .cornerRadius(3)
                        }

                        if !action.contentFilter.isEmpty {
                            Text("filtered")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.7))
                                .cornerRadius(3)
                        }
                    }

                    Text(action.command)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: $action.isEnabled)
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
