import SwiftUI

struct ClipboardBrowserStyle {
    static let popoverSize = CGSize(width: 300, height: 356)
    static let overlaySize = CGSize(width: 640, height: 420)

    var compact: Bool
    var scheme: ColorScheme
    var theme: Theme? = nil

    private var custom: Theme? { theme.flatMap { $0.id == .system ? nil : $0 } }
    private func color(_ light: String, _ dark: String) -> Color {
        Color(hex: scheme == .dark ? dark : light)
    }

    var surface: Color { color(compact ? "f0f2f5" : "f4f5f7", "242830") }
    var raised: Color { color("ffffff", "353b45") }
    var ink: Color { custom?.primaryText ?? color("242830", "eef1f6") }
    var muted: Color { custom?.secondaryText ?? color("5d6673", "adb7c7") }
    var line: Color { custom?.dividerColor ?? color("d8dce2", "464f5e") }
    var controlBorder: Color { custom?.dividerColor ?? color("bbc2cc", "586376") }
    var searchFill: Color { custom?.searchFieldBackground ?? raised }
    var tabFill: Color { custom != nil ? ink.opacity(0.08) : color("e5e8ed", "303641") }
    var footer: Color { custom != nil ? ink.opacity(0.05) : color("eceff3", "292e37") }
    var selection: Color { custom?.itemBackground ?? color("0867d9", "0867d9") }
    var selectedInk: Color { custom?.selectedText ?? .white }
    var hover: Color { custom != nil ? ink.opacity(0.08) : color("e5e8ee", "353d4a") }
    var focus: Color { custom?.accentColor ?? color("438ce5", "78b5ff") }
    var iconFill: Color { custom != nil ? ink.opacity(0.07) : color("e7ecf2", "35404e") }
    var iconInk: Color { custom?.secondaryText ?? color("56697f", "afc4df") }
    var rowRadius: CGFloat { custom?.itemCornerRadius ?? 6 }
    var rowHeight: CGFloat { compact ? 52 : max(56, (custom?.bodyFontSize ?? 13) + 17 + 2 * (custom?.itemVerticalPadding ?? 8)) }

    func separator(_ width: CGFloat = 1) -> some View {
        Rectangle().fill(line).frame(height: width).accessibilityHidden(true)
    }
}

private struct ClipboardBrowserStyleKey: EnvironmentKey {
    static let defaultValue = ClipboardBrowserStyle(compact: true, scheme: .light)
}

extension EnvironmentValues {
    var clipboardBrowserStyle: ClipboardBrowserStyle {
        get { self[ClipboardBrowserStyleKey.self] }
        set { self[ClipboardBrowserStyleKey.self] = newValue }
    }
}

struct ClipboardBrowserTitleBar<Actions: View>: View {
    let title: String
    @ViewBuilder var actions: Actions
    @Environment(\.clipboardBrowserStyle) private var style

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 13))
                .foregroundStyle(style.iconInk)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: 4) { actions }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.top, 4)
        .frame(height: 40)
    }
}

struct ClipboardBrowserIcon: View {
    let symbol: String
    var count: Int? = nil
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 12))
            if let count, count > 0 { Text(count, format: .number).font(.system(size: 10)) }
        }
        .frame(minWidth: size, minHeight: size)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

struct ClipboardBrowserSearch<Field: View>: View {
    let query: String
    let focused: Bool
    let onClear: () -> Void
    @ViewBuilder var field: Field
    @Environment(\.clipboardBrowserStyle) private var style

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7)
        HStack(spacing: style.compact ? 6 : 8) {
            Label("Search", systemImage: "magnifyingglass")
                .font(.system(size: style.compact ? 11 : 12))
                .foregroundStyle(style.muted)
                .accessibilityHidden(true)
            field
            if !query.isEmpty {
                Button(action: onClear) { ClipboardBrowserIcon(symbol: "xmark.circle.fill", size: 20) }
                    .buttonStyle(.plain)
                    .foregroundStyle(style.muted)
                    .accessibilityLabel("Clear query")
            }
        }
        .padding(.horizontal, style.compact ? 8 : 10)
        .frame(height: 36)
        .background(style.searchFill, in: shape)
        .overlay { shape.strokeBorder(focused ? style.focus : style.controlBorder) }
        .overlay { if focused { shape.stroke(style.focus.opacity(0.26), lineWidth: 3).padding(-1.5) } }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ClipboardBrowserTabs: View {
    let tab: ClipboardBrowserState.Tab
    var recentCount: Int = 0
    var pinnedCount: Int = 0
    let onSelect: (ClipboardBrowserState.Tab) -> Void
    @FocusState private var focusedTab: ClipboardBrowserState.Tab?
    @Environment(\.clipboardBrowserStyle) private var style

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.recent, title: "Recent", count: recentCount, hint: "⌘1")
            tabButton(.pinned, title: "Pinned", count: pinnedCount, hint: "⌘2")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("History views")
    }

    private func tabButton(_ value: ClipboardBrowserState.Tab, title: String, count: Int, hint: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        let selected = tab == value
        return Button {
            onSelect(value)
        } label: {
            HStack(spacing: 8) {
                if value == .pinned { Image(systemName: "pin") }
                Text(title).fontWeight(.medium)
                Text(count, format: .number).monospacedDigit().font(.system(size: 10))
                    .foregroundStyle(style.muted)
                Spacer(minLength: 0)
                Text(hint).font(.system(size: 10)).foregroundStyle(style.muted)
            }
            .font(.system(size: 12))
            .foregroundStyle(selected ? style.ink : style.muted)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(selected ? style.searchFill : style.tabFill, in: shape)
            .overlay {
                shape.strokeBorder(focusedTab == value ? style.focus : selected ? style.controlBorder : .clear,
                                   lineWidth: focusedTab == value ? 2 : 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .focused($focusedTab, equals: value)
        .accessibilityLabel(title)
        .accessibilityValue("\(count) items")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ClipboardBrowserSection: View {
    let tab: ClipboardBrowserState.Tab
    let isSearching: Bool
    let count: Int
    @Environment(\.clipboardBrowserStyle) private var style

    var body: some View {
        HStack {
            Text(isSearching ? "Search results" : tab == .recent ? "Recent" : "Pinned")
                .font(.system(size: 11, weight: .medium))
            Spacer()
            Text(count, format: .number).monospacedDigit().font(.system(size: 10))
        }
        .foregroundStyle(style.muted)
        .padding(.horizontal, 16)
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

struct ClipboardBrowserFooter: View {
    var selectedText: String? = nil
    let hasSelection: Bool
    let count: Int
    let focus: ClipboardBrowserState.Focus
    let copy: () -> Void
    @Environment(\.clipboardBrowserStyle) private var style
    @FocusState private var copyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            style.separator()
            HStack(spacing: 8) {
                if !style.compact, let selectedText {
                    Text(selectedText)
                        .font(.system(size: 11))
                        .foregroundStyle(style.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(action: copy) {
                    let shape = RoundedRectangle(cornerRadius: 6)
                    HStack(spacing: 8) {
                        Text(style.compact ? "Copy" : "Copy & close")
                        Image(systemName: style.compact ? "doc.on.doc" : "return")
                            .accessibilityHidden(true)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(style.selectedInk)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(style.selection, in: shape)
                    .opacity(hasSelection ? 1 : 0.45)
                    .overlay { if copyFocused { shape.stroke(style.focus, lineWidth: 2).padding(-2) } }
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.compact ? "Copy" : "Copy & close")
                .disabled(!hasSelection)
                .focused($copyFocused)
            }
            .padding(.horizontal, 12)
            .frame(height: style.compact ? 43 : 45)
            HStack(spacing: 12) {
                if style.compact {
                    Text("Click a row to select")
                } else {
                    Text(focus == .search ? "↑ ↓  Results" : "↑ ↓  Navigate")
                    Text("↵  Copy")
                    if focus == .search || focus == .list { Text("esc  Close") }
                }
                Spacer(minLength: 0)
                Text("\(count) \(count == 1 ? "item" : "items")").monospacedDigit()
            }
            .font(.system(size: style.compact ? 9 : 10))
            .foregroundStyle(style.muted)
            .padding(.horizontal, 12)
            .frame(height: style.compact ? 21 : 24, alignment: .top)
            .accessibilityHidden(true)
        }
        .background(style.footer)
    }
}

struct ClipboardBrowserEmptyView: View {
    let state: ClipboardBrowserState.EmptyState
    var query = ""
    let clearSearch: () -> Void
    @Environment(\.clipboardBrowserStyle) private var style

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(style.iconInk)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(style.ink)
                .lineLimit(2)
            Text(explanation)
                .font(.system(size: 11))
                .foregroundStyle(style.muted)
            if state == .noMatches {
                Button(action: clearSearch) {
                    let shape = RoundedRectangle(cornerRadius: 6)
                    Text("Clear Search")
                        .font(.system(size: 11))
                        .foregroundStyle(style.ink)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(style.searchFill, in: shape)
                        .overlay { shape.strokeBorder(style.controlBorder) }
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbol: String {
        switch state {
        case .history: return "list.clipboard"
        case .pinned: return "pin"
        case .noMatches: return "magnifyingglass"
        }
    }

    private var title: String {
        switch state {
        case .history: return "No clipboard history yet"
        case .pinned: return "No pinned items yet"
        case .noMatches: return query.isEmpty ? "No matches" : "No matches for “\(query)”"
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
