import XCTest
@testable import clipass

final class ClipboardBrowserStateTests: XCTestCase {
    private typealias State = ClipboardBrowserState

    private let oldPin = State.Item(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        content: "Work notes older",
        timestamp: Date(timeIntervalSince1970: 10),
        isPinned: true,
        tagNames: ["Work"]
    )
    private let middle = State.Item(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        content: "Home notes",
        timestamp: Date(timeIntervalSince1970: 20),
        isPinned: false,
        tagNames: ["Home"]
    )
    private let newest = State.Item(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        content: "Work notes newest",
        timestamp: Date(timeIntervalSince1970: 30),
        isPinned: false,
        tagNames: ["Work", "Quick"]
    )
    private let pinnedMatch = State.Item(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        content: "Work notes pinned",
        timestamp: Date(timeIntervalSince1970: 25),
        isPinned: true,
        tagNames: ["Work"]
    )

    private var items: [State.Item] { [oldPin, newest, middle, pinnedMatch] }

    func testV7NavigationClampsToFilteredPinnedResults() {
        var state = State(items: items)
        state.openTab(.pinned)
        state.setQuery("tag:work notes")
        XCTAssertEqual(state.handleKeyboard(.enterResults, focus: .search), .update(focus: true, reveal: true))
        XCTAssertEqual(state.selectedID, pinnedMatch.id)
        _ = state.handleKeyboard(.navigate(.previous), focus: .list)
        XCTAssertEqual(state.selectedID, pinnedMatch.id)
        _ = state.handleKeyboard(.navigate(.last), focus: .list)
        XCTAssertEqual(state.selectedID, oldPin.id)
        _ = state.handleKeyboard(.navigate(.next), focus: .list)
        XCTAssertEqual(state.selectedID, oldPin.id)
        _ = state.handleKeyboard(.navigate(.first), focus: .list)
        XCTAssertEqual(state.selectedID, pinnedMatch.id)
    }

    func testCopyReturnsSelectedItemIDAndImageItemsRefuseEditing() {
        let image = State.Item(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            content: "Image 1440×900",
            timestamp: Date(timeIntervalSince1970: 40),
            isPinned: false,
            tagNames: [],
            isImage: true
        )
        var state = State(items: items + [image])
        XCTAssertEqual(state.selectedID, image.id)
        XCTAssertEqual(state.handleKeyboard(.copyAndClose, focus: .search), .copyAndClose(image.id))

        _ = state.handleKeyboard(.enterResults, focus: .search)
        state.beginEditing()
        XCTAssertNil(state.edit)
        XCTAssertEqual(state.focus, .list)

        state.selectItem(newest.id)
        state.beginEditing()
        XCTAssertEqual(state.edit?.itemID, newest.id)
    }

    func testV5KeyboardTabSwitchKeepsQueryAndListFocus() {
        var state = State(items: items)
        state.setQuery("work notes")
        _ = state.handleKeyboard(.enterResults, focus: .search)
        XCTAssertEqual(state.handleKeyboard(.cycleTab, focus: .list), .update(focus: true, reveal: true))
        XCTAssertEqual(state.tab, .pinned)
        XCTAssertEqual(state.query, "work notes")
        XCTAssertEqual(state.selectedID, pinnedMatch.id)
        XCTAssertEqual(state.focus, .list)
    }

    func testV8KeyboardLeavesEditingAndControlActionsAlone() {
        var state = State(items: items)
        XCTAssertEqual(state.handleKeyboard(.navigate(.last), focus: .search), .passThrough)
        XCTAssertEqual(state.selectedID, newest.id)
        XCTAssertEqual(state.handleKeyboard(.copyAndClose, focus: .control), .passThrough)
        XCTAssertEqual(state.handleKeyboard(.copyAndClose, focus: .search), .copyAndClose(newest.id))
        state.setQuery("no such result")
        XCTAssertEqual(state.handleKeyboard(.enterResults, focus: .search), .passThrough)
        XCTAssertEqual(state.handleKeyboard(.copyAndClose, focus: .search), .passThrough)
        XCTAssertNil(state.selectedID)
    }

    func testV10EscapeFromHelpRestoresFocusBeforeClearingSearchOrDismissing() {
        var state = State(items: items)
        state.setQuery("work notes")
        XCTAssertEqual(state.handleKeyboard(.toggleHelp, focus: .list), .update(focus: false, reveal: false))
        XCTAssertEqual(state.transientLayer, .help)
        XCTAssertEqual(state.handleKeyboard(.copyAndClose, focus: .control), .passThrough)
        XCTAssertEqual(state.handleKeyboard(.back, focus: .control), .update(focus: true, reveal: false))
        XCTAssertNil(state.transientLayer)
        XCTAssertEqual(state.focus, .list)
        XCTAssertEqual(state.query, "work notes")
        XCTAssertEqual(state.handleKeyboard(.back, focus: .list), .update(focus: true, reveal: true))
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.focus, .search)
        XCTAssertEqual(state.handleKeyboard(.back, focus: .search), .dismiss)
    }

    func testV1SummonResetsTabQuerySelectionFocusAndLayers() {
        var state = State(items: items)
        state.openTab(.pinned)
        state.setQuery("older")
        state.beginEditing()
        state.setEditDraft("unsaved changes")
        state.showLayer(.confirmation)

        state.summon(items: items)

        XCTAssertEqual(state.tab, .recent)
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.selectedID, newest.id)
        XCTAssertEqual(state.focus, .search)
        XCTAssertEqual(state.presentation, .list)
        XCTAssertNil(state.transientLayer)
        XCTAssertNil(state.edit)
    }

    func testV1SummonClosesPreview() {
        var state = State(items: items)
        state.handle(.togglePreview, isActiveInterface: true)
        XCTAssertEqual(state.presentation, .preview)

        state.summon(items: items)

        XCTAssertEqual(state.presentation, .list)
        XCTAssertEqual(state.focus, .search)
        XCTAssertEqual(state.selectedID, newest.id)
    }

    func testV1EmptySummonHasNoStaleSelectionOrEdit() {
        var state = State(items: items)
        state.beginEditing()

        state.summon(items: [])

        XCTAssertNil(state.selectedID)
        XCTAssertNil(state.selectedItem)
        XCTAssertNil(state.edit)
        XCTAssertEqual(state.focus, .search)
        XCTAssertEqual(state.visibleItems, [])
    }

    func testV4CapturePreservesBrowsingAndJumpUsesSummonTarget() {
        var state = State(items: items)
        state.openTab(.pinned)
        state.setQuery("tag:work")
        state.selectItem(oldPin.id)
        state.setFocus(.list)
        let recopy = State.Item(id: pinnedMatch.id, content: pinnedMatch.content,
                                timestamp: Date(timeIntervalSince1970: 100), isPinned: true,
                                tagNames: pinnedMatch.tagNames)
        let updated = [oldPin, newest, middle, recopy]

        state.replaceItems(updated)
        state.noteCapture()
        state.noteCapture()

        XCTAssertEqual(state.tab, .pinned)
        XCTAssertEqual(state.query, "tag:work")
        XCTAssertEqual(state.selectedID, oldPin.id)
        XCTAssertEqual(state.focus, .list)
        XCTAssertEqual(state.visibleItems.map(\.id), [recopy.id, oldPin.id])
        XCTAssertEqual(state.unseenCaptureCount, 2)

        state.summon(items: updated)

        XCTAssertEqual(state.tab, .recent)
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.selectedID, recopy.id)
        XCTAssertEqual(state.focus, .search)
        XCTAssertEqual(state.unseenCaptureCount, 0)
    }

    func testV3RecentIncludesPinsInCopyTimeOrder() {
        let state = State(items: items)

        XCTAssertEqual(state.visibleItems.map(\.id), [newest.id, pinnedMatch.id, middle.id, oldPin.id])
    }

    func testV3PinnedContainsOnlyPinsInCopyTimeOrder() {
        var state = State(items: items)

        state.openTab(.pinned)

        XCTAssertEqual(state.visibleItems.map(\.id), [pinnedMatch.id, oldPin.id])
        XCTAssertEqual(state.selectedID, pinnedMatch.id)
    }

    func testV3PinningDoesNotPromoteAnOlderCopy() {
        var state = State(items: [middle, newest])
        let pinnedMiddle = State.Item(
            id: middle.id,
            content: middle.content,
            timestamp: middle.timestamp,
            isPinned: true,
            tagNames: middle.tagNames
        )

        state.replaceItems([pinnedMiddle, newest])

        XCTAssertEqual(state.visibleItems.map(\.id), [newest.id, middle.id])
        XCTAssertEqual(state.selectedID, newest.id)
    }

    func testV3EqualCopyTimesHaveStableOrderRegardlessOfInputOrder() {
        let sameTime = State.Item(
            id: middle.id,
            content: middle.content,
            timestamp: newest.timestamp,
            isPinned: false,
            tagNames: []
        )
        let first = State(items: [newest, sameTime])
        let second = State(items: [sameTime, newest])

        XCTAssertEqual(first.visibleItems.map(\.id), [middle.id, newest.id])
        XCTAssertEqual(second.visibleItems.map(\.id), [middle.id, newest.id])
    }

    func testV5FreeTextMatchesContentCaseInsensitively() {
        var state = State(items: items)

        state.setQuery("WORK NOTES")

        XCTAssertEqual(state.visibleItems.map(\.id), [newest.id, pinnedMatch.id, oldPin.id])
        XCTAssertEqual(state.selectedID, newest.id)
    }

    func testV5TagFilterCombinesWithFreeText() {
        var state = State(items: items)

        state.setQuery("TAG:work older")

        XCTAssertEqual(state.visibleItems.map(\.id), [oldPin.id])
        XCTAssertEqual(state.selectedID, oldPin.id)
    }

    func testV5TagsMatchNamesNotContentOrPartialTagNames() {
        var state = State(items: items)

        state.setQuery("tag:wor")
        XCTAssertEqual(state.visibleItems, [])
        XCTAssertNil(state.selectedID)

        state.setQuery("tag:quick")
        XCTAssertEqual(state.visibleItems.map(\.id), [newest.id])
    }

    func testV5MultipleTagsPreserveOverlayAnyTagSemantics() {
        var state = State(items: items)

        state.setQuery("tag:home tag:quick")

        XCTAssertEqual(state.visibleItems.map(\.id), [newest.id, middle.id])
    }

    func testV5QueryRetainsTypedSpaces() {
        var state = State(items: items)

        state.setQuery(" Work notes ")

        XCTAssertEqual(state.query, " Work notes ")
        XCTAssertEqual(state.visibleItems.map(\.id), [newest.id, pinnedMatch.id, oldPin.id])
    }

    func testV5QueryChangeSelectsFirstEvenWhenPreviousSelectionStillMatches() {
        var state = State(items: items)
        state.selectItem(oldPin.id)

        state.setQuery("notes")

        XCTAssertEqual(state.selectedID, newest.id)
    }

    func testV5TabChangeRetainsQuerySelectsFirstAndClosesLayers() {
        var state = State(items: items)
        state.setQuery("notes")
        state.handle(.togglePreview, isActiveInterface: true)
        state.showLayer(.help)

        state.openTab(.pinned)

        XCTAssertEqual(state.query, "notes")
        XCTAssertEqual(state.selectedID, pinnedMatch.id)
        XCTAssertEqual(state.presentation, .list)
        XCTAssertNil(state.transientLayer)
        XCTAssertEqual(state.focus, .search)
    }

    func testV5TabChangeKeepsListFocus() {
        var state = State(items: items)
        state.setFocus(.list)

        state.openTab(.pinned)

        XCTAssertEqual(state.focus, .list)
        XCTAssertEqual(state.selectedID, pinnedMatch.id)
    }

    func testV5TabChangeFromOtherFocusTargetsSearch() {
        for focus in [State.Focus.search, .preview, .editor, .control] {
            var state = State(items: items)
            if focus == .preview {
                state.handle(.togglePreview, isActiveInterface: true)
            } else if focus == .editor {
                state.beginEditing()
            } else {
                state.setFocus(focus)
            }

            state.openTab(.pinned)

            XCTAssertEqual(state.focus, .search, "Starting focus: \(focus)")
            XCTAssertNil(state.edit)
        }
    }

    func testV5ReopeningCurrentTabSelectsFirstMatchingResult() {
        var state = State(items: items)
        state.setQuery("notes")
        state.selectItem(oldPin.id)

        state.openTab(.recent)

        XCTAssertEqual(state.selectedID, newest.id)
        XCTAssertEqual(state.query, "notes")
    }

    func testV5NoMatchesAndEmptyPinnedHaveNoSelection() {
        var state = State(items: items)
        state.setQuery("does not exist")
        XCTAssertNil(state.selectedID)
        XCTAssertNil(state.selectedItem)

        state.setQuery("")
        state.replaceItems([newest, middle])
        state.openTab(.pinned)
        XCTAssertEqual(state.visibleItems, [])
        XCTAssertNil(state.selectedID)
        XCTAssertNil(state.selectedItem)
    }

    func testV5SnapshotRefreshPreservesValidBrowsingState() {
        var state = State(items: items)
        state.openTab(.pinned)
        state.setQuery("notes")
        state.selectItem(oldPin.id)
        state.setFocus(.list)
        let before = state

        state.replaceItems(Array(items.reversed()))

        XCTAssertEqual(state, before)
    }

    func testV5RemovingSelectionChoosesFirstRemainingMatch() {
        var state = State(items: items)
        state.openTab(.pinned)
        state.selectItem(oldPin.id)

        state.replaceItems([newest, middle, pinnedMatch])

        XCTAssertEqual(state.selectedID, pinnedMatch.id)
        XCTAssertEqual(state.tab, .pinned)
    }

    func testV5SelectionCannotTargetAnItemOutsideFilteredTab() {
        var state = State(items: items)
        state.openTab(.pinned)

        state.selectItem(newest.id)

        XCTAssertEqual(state.selectedID, pinnedMatch.id)
    }

    func testV8InactiveInterfaceRejectsAllAppActionsWithoutMutation() {
        for action in [State.Action.openTab(.pinned), .focusSearch, .togglePreview, .back] {
            var state = State(items: items)
            state.setQuery("notes")
            state.setFocus(.list)
            let before = state

            XCTAssertEqual(state.handle(action, isActiveInterface: false), .unhandled)
            XCTAssertEqual(state, before)
        }
    }

    func testV8CompositionRejectsAllAppActionsWithoutMutation() {
        for action in [State.Action.openTab(.pinned), .focusSearch, .togglePreview, .back] {
            var state = State(items: items)
            state.setQuery("notes")
            let before = state

            XCTAssertEqual(
                state.handle(action, isActiveInterface: true, isComposing: true),
                .unhandled
            )
            XCTAssertEqual(state, before)
        }
    }

    func testV8FocusSearchPreservesQueryAndSelection() {
        var state = State(items: items)
        state.setQuery("notes")
        state.selectItem(oldPin.id)
        state.setFocus(.list)

        XCTAssertEqual(state.handle(.focusSearch, isActiveInterface: true), .handled)
        XCTAssertEqual(state.focus, .search)
        XCTAssertEqual(state.query, "notes")
        XCTAssertEqual(state.selectedID, oldPin.id)
    }

    func testV8InterfacesHaveIndependentState() {
        var popover = State(items: items)
        let overlay = State(items: items)
        let originalOverlay = overlay

        popover.handle(.openTab(.pinned), isActiveInterface: true)
        popover.setQuery("older")
        popover.handle(.togglePreview, isActiveInterface: true)

        XCTAssertEqual(popover.selectedID, oldPin.id)
        XCTAssertEqual(popover.presentation, .preview)
        XCTAssertEqual(overlay, originalOverlay)
        XCTAssertEqual(overlay.selectedID, newest.id)
    }

    func testV8EmptyResultsCannotOpenPreviewOrEdit() {
        var state = State()
        let before = state

        XCTAssertEqual(state.handle(.togglePreview, isActiveInterface: true), .unhandled)
        state.beginEditing()
        state.setFocus(.preview)
        state.setFocus(.editor)

        XCTAssertEqual(state, before)
    }

    func testV10EscapeClosesOnlyTopmostTransientLayer() {
        for layer in [State.TransientLayer.help, .menu, .confirmation] {
            var state = State(items: items)
            state.setQuery("notes")
            state.handle(.togglePreview, isActiveInterface: true)
            state.showLayer(layer)

            XCTAssertEqual(state.handle(.back, isActiveInterface: true), .handled)
            XCTAssertNil(state.transientLayer)
            XCTAssertEqual(state.presentation, .preview)
            XCTAssertEqual(state.focus, .preview)
            XCTAssertEqual(state.query, "notes")
            XCTAssertEqual(state.selectedID, newest.id)
        }
    }

    func testV10EscapeClosesPreviewThenClearsQueryThenDismisses() {
        var state = State(items: items)
        state.setQuery("notes")
        state.selectItem(oldPin.id)
        state.handle(.togglePreview, isActiveInterface: true)

        XCTAssertEqual(state.handle(.back, isActiveInterface: true), .handled)
        XCTAssertEqual(state.presentation, .list)
        XCTAssertEqual(state.focus, .list)
        XCTAssertEqual(state.selectedID, oldPin.id)
        XCTAssertEqual(state.query, "notes")

        XCTAssertEqual(state.handle(.back, isActiveInterface: true), .handled)
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.selectedID, newest.id)

        let beforeDismiss = state
        XCTAssertEqual(state.handle(.back, isActiveInterface: true), .dismiss)
        XCTAssertEqual(state, beforeDismiss)
    }

    func testV10EscapeCancelsDraftWithoutMutatingOriginalContent() {
        var state = State(items: items)
        state.setQuery("notes")
        state.beginEditing()
        state.setEditDraft("unsaved text")
        state.showLayer(.confirmation)

        XCTAssertEqual(state.handle(.back, isActiveInterface: true), .handled)
        XCTAssertEqual(state.edit?.draft, "unsaved text")
        XCTAssertEqual(state.handle(.back, isActiveInterface: true), .handled)
        XCTAssertNil(state.edit)
        XCTAssertEqual(state.focus, .list)
        XCTAssertEqual(state.query, "notes")
        XCTAssertEqual(state.selectedItem?.content, newest.content)
    }

    func testV10LosingLastResultClosesPreviewWithoutStaleSelection() {
        var state = State(items: items)
        state.setQuery("newest")
        state.handle(.togglePreview, isActiveInterface: true)

        state.replaceItems([oldPin, middle, pinnedMatch])

        XCTAssertNil(state.selectedID)
        XCTAssertEqual(state.presentation, .list)
        XCTAssertEqual(state.focus, .search)
        XCTAssertEqual(state.query, "newest")
    }

    func testV10LosingEditedItemDiscardsDraftAndReconcilesSelection() {
        var state = State(items: items)
        state.beginEditing()
        state.setEditDraft("unsaved")

        state.replaceItems([oldPin, middle, pinnedMatch])

        XCTAssertNil(state.edit)
        XCTAssertEqual(state.selectedID, pinnedMatch.id)
        XCTAssertEqual(state.focus, .list)
        XCTAssertEqual(state.selectedItem?.content, pinnedMatch.content)
    }
}
