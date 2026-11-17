import Foundation

struct ClipboardBrowserState: Equatable {
    struct Item: Identifiable, Equatable {
        let id: UUID
        let content: String
        let timestamp: Date
        let isPinned: Bool
        let tagNames: [String]
    }

    enum Tab: CaseIterable, Hashable {
        case recent
        case pinned
    }

    enum Focus: Hashable {
        case search
        case list
        case preview
        case editor
        case control
    }

    enum EmptyState: Equatable {
        case history
        case pinned
        case noMatches
    }

    enum Presentation: Equatable {
        case list
        case preview
    }

    enum TransientLayer: Equatable {
        case help
        case menu
        case confirmation
    }

    struct Edit: Equatable {
        let itemID: UUID
        var draft: String
    }

    enum Action: Equatable {
        case openTab(Tab)
        case focusSearch
        case togglePreview
        case back
    }

    enum ActionResult: Equatable {
        case handled
        case unhandled
        case dismiss
    }

    private(set) var tab: Tab = .recent
    private(set) var query = ""
    private(set) var selectedID: UUID?
    private(set) var focus: Focus = .search
    private(set) var presentation: Presentation = .list
    private(set) var transientLayer: TransientLayer?
    private(set) var edit: Edit?
    private var items: [Item]

    init(items: [Item] = []) {
        self.items = Self.chronological(items)
        selectedID = self.items.first?.id
    }

    var visibleItems: [Item] {
        let tokens = query.split(whereSeparator: \.isWhitespace)
        let tagNames = tokens
            .filter { $0.lowercased().hasPrefix("tag:") }
            .map { String($0.dropFirst(4)) }
            .filter { !$0.isEmpty }
        let freeText = tokens
            .filter { !$0.lowercased().hasPrefix("tag:") }
            .joined(separator: " ")

        return items.filter { item in
            let matchesTab = tab == .recent || item.isPinned
            let matchesTags = tagNames.isEmpty || tagNames.contains { name in
                item.tagNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
            }
            let matchesText = freeText.isEmpty || item.content.localizedCaseInsensitiveContains(freeText)
            return matchesTab && matchesTags && matchesText
        }
    }

    var emptyState: EmptyState? {
        guard visibleItems.isEmpty else { return nil }
        if !query.isEmpty { return .noMatches }
        return items.isEmpty ? .history : .pinned
    }

    var selectedItem: Item? {
        visibleItems.first { $0.id == selectedID }
    }

    mutating func summon(items: [Item]) {
        self = Self(items: items)
    }

    mutating func replaceItems(_ items: [Item]) {
        self.items = Self.chronological(items)
        reconcileSelection()
    }

    mutating func setQuery(_ query: String) {
        guard self.query != query else { return }
        self.query = query
        selectedID = visibleItems.first?.id
        reconcileSelection()
    }

    mutating func openTab(_ tab: Tab) {
        let nextFocus: Focus = focus == .list ? .list : .search
        self.tab = tab
        presentation = .list
        transientLayer = nil
        edit = nil
        selectedID = visibleItems.first?.id
        focus = nextFocus
    }

    mutating func selectItem(_ id: UUID) {
        guard visibleItems.contains(where: { $0.id == id }) else { return }
        selectedID = id
        reconcileSelection()
    }

    mutating func setFocus(_ focus: Focus) {
        switch focus {
        case .preview:
            guard presentation == .preview else { return }
        case .editor:
            guard edit != nil else { return }
        case .search, .list, .control:
            break
        }
        self.focus = focus
    }

    mutating func showLayer(_ layer: TransientLayer) {
        transientLayer = layer
    }

    mutating func beginEditing() {
        guard let item = selectedItem else { return }
        edit = Edit(itemID: item.id, draft: item.content)
        presentation = .list
        transientLayer = nil
        focus = .editor
    }

    mutating func setEditDraft(_ draft: String) {
        edit?.draft = draft
    }

    // These are explicit app actions, not raw key events. Native adapters own event routing.
    @discardableResult
    mutating func handle(
        _ action: Action,
        isActiveInterface: Bool,
        isComposing: Bool = false
    ) -> ActionResult {
        guard isActiveInterface, !isComposing else { return .unhandled }
        switch action {
        case .openTab(let tab):
            openTab(tab)
        case .focusSearch:
            focus = .search
        case .togglePreview:
            guard selectedItem != nil, edit == nil else { return .unhandled }
            if presentation == .preview {
                presentation = .list
                focus = .list
            } else {
                presentation = .preview
                focus = .preview
            }
        case .back:
            if transientLayer != nil {
                transientLayer = nil
            } else if edit != nil {
                edit = nil
                focus = .list
            } else if presentation == .preview {
                presentation = .list
                focus = .list
            } else if !query.isEmpty {
                setQuery("")
            } else {
                return .dismiss
            }
        }
        return .handled
    }

    private mutating func reconcileSelection() {
        let visible = visibleItems
        if !visible.contains(where: { $0.id == selectedID }) {
            selectedID = visible.first?.id
        }
        if let edit, edit.itemID != selectedID {
            self.edit = nil
            focus = selectedID == nil ? .search : .list
        }
        if selectedID == nil {
            presentation = .list
            if focus == .preview {
                focus = .search
            }
        }
    }

    private static func chronological(_ items: [Item]) -> [Item] {
        items.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp > rhs.timestamp
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
