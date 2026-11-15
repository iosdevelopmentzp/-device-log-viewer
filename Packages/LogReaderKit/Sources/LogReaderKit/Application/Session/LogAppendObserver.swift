import Foundation

@MainActor
public protocol LogAppendObserver: AnyObject {
    func session(_ session: LogSession, didAppend range: Range<Int>)
}
