import Foundation

@MainActor
public protocol LogTableUpdateReceiver: AnyObject {
    func apply(_ event: LogRowsEvent)
}
