import Foundation

public protocol LogSource: AnyObject, Sendable {
    var url: URL { get }
    func events() -> AsyncStream<LogSourceEvent>
    func stop()
}
