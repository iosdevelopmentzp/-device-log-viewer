import Foundation
import Testing
@testable import LogReaderKit

@MainActor
struct SidebarContentSearchTests {

    private let searcher = FakeFileContentSearcher()
    private let first = SearchableFile(url: URL(fileURLWithPath: "/tmp/logs/log-1.txt"), size: 10)
    private let second = SearchableFile(url: URL(fileURLWithPath: "/tmp/logs/log-2.txt"), size: 20)

    @Test func publishesResultsAfterTheDebounce() async {
        let search = makeSearch(debounce: .milliseconds(30))
        searcher.setResult(.count(3), for: first.url.path)

        search.update(query: " socket ", isRegex: false, files: [first, second])

        #expect(search.isSearching)
        #expect(search.results == nil)
        #expect(searcher.calls.isEmpty)
        await Eventually.wait { search.isSearching == false }
        #expect(search.results == [first.url.path: .count(3), second.url.path: .count(0)])
        #expect(searcher.queries == ["socket", "socket"])
    }

    @Test func aNewQueryCancelsTheOldOne() async {
        let search = makeSearch(debounce: .milliseconds(30))

        search.update(query: "a", isRegex: false, files: [first])
        search.update(query: "b", isRegex: false, files: [second])

        await Eventually.wait { search.isSearching == false }
        #expect(searcher.calls == [second.url.path])
        #expect(search.results == [second.url.path: .count(0)])
    }

    @Test func skippedFilesKeepTheirResult() async {
        let search = makeSearch(debounce: .milliseconds(1))
        searcher.setResult(.skipped, for: first.url.path)

        search.update(query: "a", isRegex: false, files: [first])

        await Eventually.wait { search.isSearching == false }
        #expect(search.results == [first.url.path: .skipped])
    }

    @Test func emptyQueryClearsTheResults() async {
        let search = makeSearch(debounce: .milliseconds(1))
        search.update(query: "a", isRegex: false, files: [first])
        await Eventually.wait { search.results != nil }

        search.update(query: "  ", isRegex: false, files: [first])

        #expect(search.results == nil)
        #expect(search.isSearching == false)
    }

    @Test func invalidRegexGivesEmptyResults() async {
        let search = makeSearch(debounce: .milliseconds(1))

        search.update(query: "a(b", isRegex: true, files: [first])

        await Eventually.wait { search.isSearching == false }
        #expect(search.results == [:])
        #expect(searcher.calls.isEmpty)
    }

    @Test func stopCancelsTheSearch() async throws {
        let search = makeSearch(debounce: .milliseconds(20))

        search.update(query: "a", isRegex: false, files: [first])
        search.stop()
        try await Task.sleep(for: .milliseconds(60))

        #expect(search.isSearching == false)
        #expect(search.results == nil)
        #expect(searcher.calls.isEmpty)
    }

    @Test func unchangedFilesAreNotReadAgain() async {
        let search = makeSearch(debounce: .milliseconds(10))
        searcher.setResult(.count(2), for: first.url.path)
        search.update(query: "a", isRegex: false, files: [first, second])
        await Eventually.wait { search.isSearching == false }
        #expect(searcher.calls == [first.url.path, second.url.path])

        let grown = SearchableFile(url: second.url, size: 25)
        search.update(query: "a", isRegex: false, files: [first, grown])
        await Eventually.wait { search.isSearching == false }
        #expect(searcher.calls == [first.url.path, second.url.path, second.url.path])
        #expect(search.results?[first.url.path] == .count(2))

        search.update(query: "b", isRegex: false, files: [first, grown])
        await Eventually.wait { search.isSearching == false }
        #expect(searcher.calls.count == 5)
    }

    private func makeSearch(debounce: Duration) -> SidebarContentSearch {
        SidebarContentSearch(searcher: searcher, debounce: debounce, sizeLimit: 1_000)
    }
}
