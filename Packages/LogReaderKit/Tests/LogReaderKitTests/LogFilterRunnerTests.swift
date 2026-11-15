import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct LogFilterRunnerTests {

    @Test func runReturnsTheFilteredIndices() async {
        let runner = LogFilterRunner(debounce: .milliseconds(1))

        let result = await runner.run(Self.request(text: "payment"), debounced: false)

        #expect(result == FilterResult(visible: [1], findMatches: []))
    }

    @Test func runCollectsFindMatchesWithoutHidingRows() async {
        let runner = LogFilterRunner(debounce: .milliseconds(1))
        var request = Self.request(text: "")
        request = FilterRequest(
            content: request.content,
            range: request.range,
            filter: request.filter,
            findQuery: TextQuery("noise"),
            findTerms: []
        )

        let result = await runner.run(request, debounced: true)

        #expect(result == FilterResult(visible: [0, 1, 2], findMatches: [2]))
    }

    @Test func aNewRunCancelsTheSupersededRun() async throws {
        let runner = LogFilterRunner(debounce: .milliseconds(200))
        let first = Task { await runner.run(Self.request(text: "socket"), debounced: true) }
        try await Task.sleep(for: .milliseconds(20))

        let second = await runner.run(Self.request(text: "payment"), debounced: false)

        #expect(await first.value == nil)
        #expect(second?.visible == [1])
    }

    @Test func cancelReturnsNil() async throws {
        let runner = LogFilterRunner(debounce: .milliseconds(200))
        let run = Task { await runner.run(Self.request(text: "socket"), debounced: true) }
        try await Task.sleep(for: .milliseconds(20))

        runner.cancel()

        #expect(await run.value == nil)
    }
}

// MARK: - Private

private extension LogFilterRunnerTests {

    static func request(text: String) -> FilterRequest {
        var fixtures = LogFixtures()
        var content = LogContent(profile: LogFixtures.profile)
        content.append(fixtures.batch(LogFixtures.sample))
        var filter = LogFilter.all
        filter.text = text
        return FilterRequest(content: content, range: 0..<content.records.count, filter: filter, findQuery: nil, findTerms: [])
    }
}
