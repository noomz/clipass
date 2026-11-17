import SwiftUI

struct ClipboardBrowserTabs: View {
    let tab: ClipboardBrowserState.Tab
    let onSelect: (ClipboardBrowserState.Tab) -> Void
    @FocusState private var focusedTab: ClipboardBrowserState.Tab?

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.recent, title: "Recent", hint: "⌘1")
            tabButton(.pinned, title: "Pinned", hint: "⌘2")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("History views")
    }

    private func tabButton(_ value: ClipboardBrowserState.Tab, title: String, hint: String) -> some View {
        Button {
            onSelect(value)
        } label: {
            HStack(spacing: 6) {
                if value == .pinned {
                    Image(systemName: "pin")
                }
                Text(title)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(tab == value ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .focused($focusedTab, equals: value)
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(focusedTab == value ? Color.accentColor : .clear, lineWidth: 2)
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}

struct ClipboardBrowserEmptyView: View {
    let state: ClipboardBrowserState.EmptyState
    let clearSearch: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: state == .noMatches ? "magnifyingglass" : "doc.on.clipboard")
                .font(.title2)
            Text(title)
                .font(.headline)
            Text(explanation)
                .font(.caption)
                .multilineTextAlignment(.center)
            if state == .noMatches {
                Button("Clear Search", action: clearSearch)
            }
        }
        .foregroundStyle(.secondary)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch state {
        case .history: return "No clipboard history yet"
        case .pinned: return "No pinned items yet"
        case .noMatches: return "No matches"
        }
    }

    private var explanation: String {
        switch state {
        case .history: return "Copy text to get started."
        case .pinned: return "Pin a useful copy from its action menu."
        case .noMatches: return "Try different text or a tag filter such as tag:work."
        }
    }
}
