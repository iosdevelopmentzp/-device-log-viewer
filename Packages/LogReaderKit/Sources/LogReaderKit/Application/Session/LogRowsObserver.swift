import Foundation

@MainActor
public protocol LogRowsObserver: AnyObject {
    func handle(_ event: LogRowsEvent)
}
