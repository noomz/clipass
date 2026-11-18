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
        case cycleTab
        case focusSearch
        case enterResults
        case navigate(Navigation)
        case togglePreview
        case toggleHelp
        case copyAndClose
        case back
    }

    enum Navigation: Equatable {
        case previous, next, first, last
    }

    enum ActionResult: Equatable {
        case handled
        case unhandled
        case copyAndClose(String)
        case dismiss
    }

    private(set) var tab: Tab = .recent
    private(set) var query = ""
    private(set) var selectedID: UUID?
    private(set) var focus: Focus = .search
    private(set) var presentation: Presentation = .list
    private(set) var transientLayer: TransientLayer?
    private(set) var edit: Edit?
    private(set) var unseenCaptureCount = 0
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

    mutating func noteCapture() {
        unseenCaptureCount += 1
    }

    mutating func replaceItems(_ items: [Item]) {
        self.items = Self.chronological(items)
        reconcileSelection()
    }

    mutating func setQuery(_ query: String) {
        guard self.query != query else { return }
        self.query = query
        presentation = .list
        if focus == .preview { focus = .search }
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

    enum KeyboardEffect: Equatable {
        case passThrough
        case dismiss
        case copyAndClose(String)
        case update(focus: Bool, reveal: Bool)
    }

    mutating func handleKeyboard(_ action: Action, focus actualFocus: Focus) -> KeyboardEffect {
        if transientLayer == nil { setFocus(actualFocus) }
        let before = self
        switch handle(action, isActiveInterface: true) {
        case .unhandled: return .passThrough
        case .dismiss: return .dismiss
        case .copyAndClose(let content): return .copyAndClose(content)
        case .handled:
            let updateFocus = transientLayer == nil && (before.focus != focus || before.transientLayer != nil)
            switch action {
            case .openTab, .cycleTab: return .update(focus: true, reveal: true)
            case .focusSearch: return .update(focus: true, reveal: false)
            case .enterResults, .navigate: return .update(focus: updateFocus, reveal: true)
            default: return .update(focus: updateFocus, reveal: before.query != query)
            }
        }
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
        case .cycleTab:
            openTab(tab == .recent ? .pinned : .recent)
        case .focusSearch:
            if transientLayer == .help { transientLayer = nil }
            focus = .search
        case .enterResults:
            guard focus == .search, transientLayer == nil, selectedItem != nil else { return .unhandled }
            presentation = .list
            focus = .list
        case .navigate(let navigation):
            guard focus == .list, presentation == .list, transientLayer == nil, edit == nil else { return .unhandled }
            let visible = visibleItems
            guard !visible.isEmpty else { return .unhandled }
            let current = visible.firstIndex { $0.id == selectedID } ?? 0
            let index = switch navigation {
            case .previous: max(current - 1, 0)
            case .next: min(current + 1, visible.count - 1)
            case .first: 0
            case .last: visible.count - 1
            }
            selectedID = visible[index].id
        case .togglePreview:
            guard selectedItem != nil, edit == nil, transientLayer != .confirmation else { return .unhandled }
            transientLayer = nil
            if presentation == .preview {
                presentation = .list
                focus = .list
            } else {
                presentation = .preview
                focus = .preview
            }
        case .toggleHelp:
            switch transientLayer {
            case nil: transientLayer = .help
            case .help: transientLayer = nil
            default: return .unhandled
            }
        case .copyAndClose:
            guard [.search, .list, .preview].contains(focus), transientLayer == nil,
                  edit == nil, let selectedItem else { return .unhandled }
            return .copyAndClose(selectedItem.content)
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
                focus = .search
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
