import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct SearchTermsViewModelTests {

    @Test func startsEmpty() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchTermsViewModel(session: harness.session)

        #expect(model.isEmpty)
        #expect(model.items.isEmpty)
        #expect(model.canAdd)
        #expect(model.containsTitle == "Also contains")
        #expect(model.excludesTitle == "Does not contain")
    }

    @Test func addEditNegateAndRemove() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchTermsViewModel(session: harness.session)

        model.add()
        model.add()
        model.setText(id: 1, "retry")
        model.setNegated(id: 1, true)

        #expect(model.isEmpty == false)
        #expect(model.items == [
            SearchTermItem(id: 0, text: "", isNegated: false),
            SearchTermItem(id: 1, text: "retry", isNegated: true)
        ])

        model.remove(id: 0)

        #expect(model.items == [SearchTermItem(id: 0, text: "retry", isNegated: true)])
        #expect(harness.session.filterState.extraTerms == [SearchTerm(text: "retry", isNegated: true)])
    }

    @Test func cannotAddMoreThanThree() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = SearchTermsViewModel(session: harness.session)

        model.add()
        model.add()
        model.add()
        model.add()

        #expect(model.items.count == 3)
        #expect(model.canAdd == false)
    }
}
