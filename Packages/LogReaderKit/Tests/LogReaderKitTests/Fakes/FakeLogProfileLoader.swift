import Foundation
import LogReaderKit
import Synchronization

final class FakeLogProfileLoader: LogProfileLoader {

    private struct State {
        var results: [URL: ProfileLoadResult] = [:]
        var loadedRoots: [URL] = []
        var writtenRoots: [URL] = []
        var errorToThrow: (any Error)?
    }

    private let state = Mutex(State())

    var loadedRoots: [URL] {
        state.withLock { $0.loadedRoots }
    }

    var writtenRoots: [URL] {
        state.withLock { $0.writtenRoots }
    }

    func setResult(_ result: ProfileLoadResult, for root: URL) {
        state.withLock { $0.results[root] = result }
    }

    func setError(_ error: (any Error)?) {
        state.withLock { $0.errorToThrow = error }
    }

    func load(projectRoot: URL) -> ProfileLoadResult {
        state.withLock { state in
            state.loadedRoots.append(projectRoot)
            return state.results[projectRoot] ?? .missing
        }
    }

    func modificationDate(projectRoot: URL) -> Date? {
        state.withLock { state in
            switch state.results[projectRoot] {
            case .loaded(_, let modifiedAt): modifiedAt
            case .failed(_, let modifiedAt): modifiedAt
            case .missing, nil: nil
            }
        }
    }

    func writeExample(projectRoot: URL) throws {
        try state.withLock { state in
            if let error = state.errorToThrow {
                throw error
            }
            state.writtenRoots.append(projectRoot)
        }
    }
}
