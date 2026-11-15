import Foundation
import LogReaderKit
import Synchronization

final class FakeFileWriter: FileWriter {

    struct Write: Equatable {
        let url: URL
        let data: Data
    }

    private struct State {
        var writes: [Write] = []
        var errorToThrow: (any Error)?
        var gate: DispatchSemaphore?
    }

    private let state = Mutex(State())

    var writes: [Write] {
        state.withLock { $0.writes }
    }

    func fail(with error: any Error) {
        state.withLock { $0.errorToThrow = error }
    }

    func hold(until gate: DispatchSemaphore) {
        state.withLock { $0.gate = gate }
    }

    func write(_ data: Data, to url: URL) throws {
        let gate = state.withLock { $0.gate }
        gate?.wait()
        try state.withLock { state in
            if let error = state.errorToThrow {
                throw error
            }
            state.writes.append(Write(url: url, data: data))
        }
    }
}
