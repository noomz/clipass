import SwiftUI
import SwiftData

struct HooksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Hook.order) private var hooks: [Hook]
    @State private var showAddSheet = false
    @State private var editingHook: Hook?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Automation Hooks")
                    .font(.headline)

                Spacer()

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if hooks.isEmpty {
                VStack {
                    Spacer()
                    Text("No hooks yet")
                        .foregroundColor(.secondary)
                    Text("Add hooks to run commands on clipboard events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(hooks) { hook in
                            HookRow(hook: hook) {
                                editingHook = hook
                            } onDelete: {
                                deleteHook(hook)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            HookEditorView(hook: nil)
        }
        .sheet(item: $editingHook) { hook in
            HookEditorView(hook: hook)
        }
    }

    private func deleteHook(_ hook: Hook) {
        modelContext.delete(hook)
    }
}

struct HookRow: View {
    @Bindable var hook: Hook
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(hook.name)
                            .font(.body)
                            .foregroundColor(.primary)

                        if let sourceApp = hook.sourceAppFilter, !sourceApp.isEmpty {
                            Text(appNameFromBundleId(sourceApp))
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.7))
                                .cornerRadius(3)
                        }
                    }

                    Text(hook.command)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: $hook.isEnabled)
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

    private func appNameFromBundleId(_ bundleId: String) -> String {
        // Extract app name from bundle ID (e.g., "com.apple.Terminal" -> "Terminal")
        if let lastComponent = bundleId.split(separator: ".").last {
            return String(lastComponent)
        }
        return bundleId
    }
}
