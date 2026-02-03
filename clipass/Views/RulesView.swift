import SwiftUI
import SwiftData

struct RulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TransformRule.order) private var rules: [TransformRule]
    @State private var showAddRule = false
    @State private var selectedRule: TransformRule?
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text("Transform Rules")
                    .font(.headline)

                Spacer()

                Button(action: { showAddRule = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if rules.isEmpty {
                VStack {
                    Spacer()
                    Text("No rules yet")
                        .foregroundColor(.secondary)
                    Text("Add rules to auto-transform clipboard content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(rules) { rule in
                            RuleRow(rule: rule) {
                                selectedRule = rule
                            } onDelete: {
                                deleteRule(rule)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
                .foregroundColor(.orange)
                Spacer()
            }
            .padding()
        }
        .frame(width: 300, height: 350)
        .sheet(isPresented: $showAddRule) {
            RuleEditorView(rule: nil)
        }
        .sheet(item: $selectedRule) { rule in
            RuleEditorView(rule: rule)
        }
        .confirmationDialog(
            "Reset to Default Rules",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                TransformEngine.resetToDefaultRules(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all custom rules and restore the default rules.")
        }
    }

    private func deleteRule(_ rule: TransformRule) {
        modelContext.delete(rule)
    }
}

struct RuleRow: View {
    @Bindable var rule: TransformRule
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(rule.name)
                            .font(.body)
                            .foregroundColor(.primary)

                        if let sourceApp = rule.sourceAppFilter, !sourceApp.isEmpty {
                            Text(appNameFromBundleId(sourceApp))
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.7))
                                .cornerRadius(3)
                        }
                    }

                    Text(rule.pattern)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: $rule.isEnabled)
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
