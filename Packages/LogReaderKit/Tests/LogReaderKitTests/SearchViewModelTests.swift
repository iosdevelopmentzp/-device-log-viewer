import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct SearchViewModelTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())

    @Test func scopeChangesArePersistedInSettings() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchViewModel(session: harness.session, settings: settings)

        #expect(model.isScopeDefault)
        #expect(model.scopeSummary == "Search in: Message and fields")

        model.toggleScope(id: "tags")
        #expect(harness.session.filterState.searchScope == SearchScope(ids: ["message", "tags"]))
        #expect(settings.searchScope == SearchScope(ids: ["message", "tags"]))
        #expect(model.isScopeDefault == false)
        #expect(model.scopeSummary == "Search in: Message and fields, Tags")
        #expect(model.scopeOptions.filter(\.isOn).map(\.title) == ["Message and fields", "Tags"])
        #expect(model.scopeOptions.map(\.id) == ["message", "tags", "category", "source", "level"])
        #expect(model.scopeOptions[1] == SearchScopeOption(id: "tags", title: "Tags", isOn: true))

        model.useAllScopes()
        #expect(settings.searchScope == SearchScope(ids: ["message", "tags", "category", "source", "level"]))

        model.useMessageScope()
        #expect(settings.searchScope == .message)
    }

    @Test func regexToggleIsPersistedInSettings() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchViewModel(session: harness.session, settings: settings)

        #expect(model.isRegex == false)

        model.isRegex = true

        #expect(harness.session.filterState.isRegex)
        #expect(settings.searchUsesRegex)

        model.isRegex = false

        #expect(harness.session.filterState.isRegex == false)
        #expect(settings.searchUsesRegex == false)
    }

    @Test func regexErrorDescribesAnInvalidPattern() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchViewModel(session: harness.session, settings: settings)

        model.text = "user("
        #expect(model.regexError == nil)
        #expect(model.isTextValid)
        #expect(model.fieldHelp == "")

        model.isRegex = true
        let error = model.regexError
        #expect(error?.hasPrefix("Invalid expression: ") == true)
        #expect(error?.contains("\n") == false)
        #expect(model.isTextValid == false)
        #expect(model.fieldHelp == error)

        model.text = "user\\d+"
        #expect(model.regexError == nil)
        #expect(model.isTextValid)
    }

    @Test func modeAndPrompt() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchViewModel(session: harness.session, settings: settings)

        #expect(model.modeOptions.map(\.title) == ["Filter", "Find"])
        #expect(model.prompt == "Filter entries (⌘F)")

        model.mode = .find

        #expect(harness.session.filterState.searchMode == .find)
        #expect(model.prompt == "Find in entries (⌘F)")
    }

    @Test func findControlsAndPosition() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = SearchViewModel(session: harness.session, settings: settings)
        model.mode = .find
        await harness.waitForFilter()

        #expect(model.showsFindControls == false)
        model.text = "zzz"
        await harness.waitForFilter()
        #expect(model.showsFindControls)
        #expect(model.showsClearButton)
        #expect(model.positionText == "No matches")
        #expect(model.canNavigate == false)

        model.text = "e"
        await harness.waitForFilter()
        #expect(model.positionText == "–/3")
        #expect(model.canNavigate)

        model.submit()
        #expect(harness.observer.events.last == .select(row: 0))
        harness.session.selectedRecords = [0]
        #expect(model.positionText == "1/3")

        model.clear()
        #expect(model.text == "")
        #expect(model.showsClearButton == false)
    }

    @Test func commitSearchRecordsNonEmptyText() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchViewModel(session: harness.session, settings: settings)

        model.text = "   "
        model.commitSearch()
        #expect(model.hasHistory == false)

        model.mode = .find
        model.toggleScope(id: "tags")
        model.text = "payment"
        model.commitSearch()
        model.commitSearch()

        let entries = settings.searchHistory.entries
        #expect(model.hasHistory)
        #expect(entries.count == 1)
        #expect(entries.first?.text == "payment")
        #expect(entries.first?.mode == .find)
        #expect(entries.first?.scope == SearchScope(ids: ["message", "tags"]))
        #expect(entries.first?.isRegex == false)
        #expect(model.historyViewModel === model.historyViewModel)
    }

    @Test func commitSearchRecordsTheRegexFlag() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchViewModel(session: harness.session, settings: settings)

        model.isRegex = true
        model.text = "pay(ment)?"
        model.commitSearch()

        #expect(settings.searchHistory.entries.first?.isRegex == true)
    }

    @Test func addConditionAddsAnExtraTermUntilTheLimit() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchViewModel(session: harness.session, settings: settings)

        #expect(model.canAddCondition)

        model.addCondition()
        model.addCondition()
        model.addCondition()

        #expect(harness.session.filterState.extraTerms.count == 3)
        #expect(model.canAddCondition == false)
    }

    @Test func findControlsShowForExtraTermsWithoutMainText() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchViewModel(session: harness.session, settings: settings)
        model.mode = .find

        #expect(model.showsFindControls == false)

        harness.session.setExtraTerms([SearchTerm(text: "socket", isNegated: false)])

        #expect(model.showsFindControls)
    }
}
