import LogReaderKit

@MainActor
final class FakeLogRowsObserver: LogRowsObserver {

    private(set) var events: [LogRowsEvent] = []

    func handle(_ event: LogRowsEvent) {
        events.append(event)
    }

    func removeAll() {
        events = []
    }
}
