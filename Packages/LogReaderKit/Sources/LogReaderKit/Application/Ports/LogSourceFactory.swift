import Foundation
import LogReaderCore

public protocol LogSourceFactory: AnyObject {
    func makeSource(for url: URL, profile: LogProfile) -> any LogSource
}
