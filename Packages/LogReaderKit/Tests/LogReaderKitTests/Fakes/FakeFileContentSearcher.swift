import Foundation
import LogReaderCore
import LogReaderKit
import Synchronization

final class FakeFileContentSearcher: FileContentSearcher {

    private struct State {
        var results: [String: FileSearchResult] = [:]
        var calls: [String] = []
        var queries: [String] = []
    }

    private let state = Mutex(State())

    var calls: [String] {
        state.withLock { $0.calls }
    }

    var queries: [String] {
        state.withLock { $0.queries }
    }

    func setResult(_ result: FileSearchResult, for path: String) {
        state.withLock { $0.results[path] = result }
    }

    func countMatches(of query: TextQuery, in url: URL, sizeLimit: Int) throws -> FileSearchResult {
        state.withLock { state in
            state.calls.append(url.path)
            state.queries.append(query.text)
            return state.results[url.path] ?? .count(0)
        }
    }
}
