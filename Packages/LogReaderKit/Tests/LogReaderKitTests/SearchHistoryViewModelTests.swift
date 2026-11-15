import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct SearchHistoryViewModelTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

    @Test func itemsShowEntriesAndFollowTheFilterText() {
        let model = makeModel()
        #expect(model.isEmpty)

        add("Socket connected", mode: .find, scope: SearchScope(ids: ["message", "tags"]), at: 1)
        add("payment", mode: .filter, scope: .message, at: 2)

        #expect(model.isEmpty == false)
        #expect(model.items.map(\.text) == ["payment", "Socket connected"])
        let socket = model.items[1]
        #expect(socket.modeTitle == "Find")
        #expect(socket.scopeTitle == "Message and fields, Tags")
        #expect(socket.isPinned == false)
        #expect(socket.pinSymbolName == "pin")
        #expect(socket.timeText.isEmpty == false)

        model.filterText = "SOCKET"
        #expect(model.items.map(\.text) == ["Socket connected"])
    }

    @Test func applySetsTheSessionAndMovesTheEntryToTheTop() async {
        let model = makeModel()
        let socket = add("socket", mode: .find, scope: SearchScope(ids: ["message", "tags"]), at: 1)
        add("payment", mode: .filter, scope: .message, at: 2)

        model.apply(id: socket.id)

        #expect(harness.session.filterState.searchText == "socket")
        #expect(harness.session.filterState.searchMode == .find)
        #expect(harness.session.filterState.searchScope == SearchScope(ids: ["message", "tags"]))
        #expect(settings.searchScope == SearchScope(ids: ["message", "tags"]))
        #expect(model.items.map(\.text) == ["socket", "payment"])
        #expect(model.items.first?.id == socket.id)
        await harness.waitForFilter()
    }

    @Test func applyRestoresTheRegexFlag() async {
        let model = makeModel()
        let regex = add("pay(ment)?", mode: .filter, scope: .message, isRegex: true, at: 1)
        add("socket", mode: .filter, scope: .message, at: 2)

        #expect(model.items.map(\.isRegexTitle) == ["", "regex"])

        model.apply(id: regex.id)

        #expect(harness.session.filterState.isRegex)
        #expect(settings.searchUsesRegex)
        await harness.waitForFilter()
    }

    @Test func applySelectedUsesTheSelectionOrTheFirstItem() async {
        let model = makeModel()
        let socket = add("socket", mode: .filter, scope: .message, at: 1)
        add("payment", mode: .filter, scope: .message, at: 2)

        model.applySelected()
        #expect(harness.session.filterState.searchText == "payment")

        model.selectedID = socket.id
        model.applySelected()
        #expect(harness.session.filterState.searchText == "socket")
        await harness.waitForFilter()
    }

    @Test func removePinAndClear() {
        let model = makeModel()
        let socket = add("socket", mode: .filter, scope: .message, at: 1)
        let payment = add("payment", mode: .filter, scope: .message, at: 2)
        let debug = add("debug", mode: .filter, scope: .message, at: 3)

        model.selectedID = debug.id
        model.remove(id: debug.id)
        #expect(model.items.map(\.text) == ["payment", "socket"])
        #expect(model.selectedID == nil)

        model.togglePin(id: socket.id)
        #expect(model.items.map(\.text) == ["socket", "payment"])
        #expect(model.items.first?.isPinned == true)
        #expect(model.items.first?.pinSymbolName == "pin.fill")

        model.selectedID = payment.id
        model.clear()
        #expect(model.items.map(\.text) == ["socket"])
        #expect(model.selectedID == nil)
    }
}

// MARK: - Private

private extension SearchHistoryViewModelTests {

    func makeModel() -> SearchHistoryViewModel {
        SearchHistoryViewModel(session: harness.session, settings: settings)
    }

    @discardableResult
    func add(_ text: String, mode: SearchMode, scope: SearchScope, at time: TimeInterval) -> RecentSearch {
        add(text, mode: mode, scope: scope, isRegex: false, at: time)
    }

    @discardableResult
    func add(_ text: String, mode: SearchMode, scope: SearchScope, isRegex: Bool, at time: TimeInterval) -> RecentSearch {
        let entry = RecentSearch(
            id: UUID(),
            text: text,
            mode: mode,
            scope: scope,
            isRegex: isRegex,
            date: Date(timeIntervalSince1970: time),
            isPinned: false
        )
        settings.searchHistory = settings.searchHistory.adding(entry)
        return entry
    }
}
