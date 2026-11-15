import LogReaderKit

@MainActor
final class FakeLogTableUpdateReceiver: LogTableUpdateReceiver {

    private(set) var events: [LogRowsEvent] = []

    func apply(_ event: LogRowsEvent) {
        events.append(event)
    }

    func removeAll() {
        events = []
    }
}
