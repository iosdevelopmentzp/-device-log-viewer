import Foundation
import LogReaderCore
import Synchronization

final class FakeLogSource: LogSource {

    let url: URL

    private let stream: AsyncStream<LogSourceEvent>
    private let continuation: AsyncStream<LogSourceEvent>.Continuation
    private let stopCount = Mutex(0)

    var isStopped: Bool {
        stopCount.withLock { $0 > 0 }
    }

    init(url: URL) {
        self.url = url
        (stream, continuation) = AsyncStream.makeStream(of: LogSourceEvent.self)
    }

    func events() -> AsyncStream<LogSourceEvent> {
        stream
    }

    func stop() {
        stopCount.withLock { $0 += 1 }
        continuation.finish()
    }

    func send(_ event: LogSourceEvent) {
        continuation.yield(event)
    }
}
