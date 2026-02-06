import SwiftUI
import SwiftData

struct IgnoredAppsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IgnoredApp.createdAt) private var ignoredApps: [IgnoredApp]
    @State private var showAddSheet = false
    @State private var editingApp: IgnoredApp?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ignored Apps")
                    .font(.headline)

                Spacer()

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if ignoredApps.isEmpty {
                VStack {
                    Spacer()
                    Text("No ignored apps")
                        .foregroundColor(.secondary)
                    Text("Add apps to exclude from clipboard capture")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(ignoredApps) { app in
                            IgnoredAppRow(app: app) {
                                editingApp = app
                            } onDelete: {
                                deleteApp(app)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            IgnoredAppEditorView(app: nil)
        }
        .sheet(item: $editingApp) { app in
            IgnoredAppEditorView(app: app)
        }
    }

    private func deleteApp(_ app: IgnoredApp) {
        modelContext.delete(app)
    }
}

struct IgnoredAppRow: View {
    @Bindable var app: IgnoredApp
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(app.bundleId)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: $app.isEnabled)
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
