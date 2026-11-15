import Foundation

public protocol FileWriter: AnyObject, Sendable {
    func write(_ data: Data, to url: URL) throws
}
