import SwiftUI

extension View {
    func clipboardPreview(
        _ item: ClipboardItem?, tags: [UUID: [TagInfo]], patterns: [RedactionPattern],
        focus: FocusState<ClipboardBrowserState.Focus?>.Binding
    ) -> some View {
        opacity(item == nil ? 1 : 0)
            .disabled(item != nil)
            .allowsHitTesting(item == nil)
            .accessibilityHidden(item != nil)
            .overlay {
                if let item {
                    ClipboardBrowserPreview(item: item, tags: tags[item.id] ?? [], patterns: patterns, focus: focus)
                        .id(item.id)
                }
            }
    }
}

private struct ClipboardBrowserPreview: View {
    let item: ClipboardItem
    let tags: [TagInfo]
    let patterns: [RedactionPattern]
    let focus: FocusState<ClipboardBrowserState.Focus?>.Binding
    @Environment(\.clipboardBrowserStyle) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.system(size: 12, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text([item.sourceAppDisplayName ?? "Unknown app", item.timestamp.formatted(date: .abbreviated, time: .shortened)]
                .joined(separator: " · "))
                .font(.system(size: 10))
                .foregroundStyle(style.muted)
            if !tags.isEmpty {
                Text(tags.map { "#\($0.name)" }.joined(separator: " "))
                    .font(.system(size: 10))
                    .foregroundStyle(style.muted)
            }
            ScrollView {
                Text(DisplayFormatter.redact(item.content, patterns: patterns))
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(style.searchFill, in: RoundedRectangle(cornerRadius: 6))
            .focusable()
            .focused(focus, equals: .preview)
            .accessibilityLabel("Preview content")
        }
        .foregroundStyle(style.ink)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ClipboardRowPreviewButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ClipboardBrowserIcon(symbol: "eye")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Preview selected item")
        .help("Preview selected item")
    }
}
