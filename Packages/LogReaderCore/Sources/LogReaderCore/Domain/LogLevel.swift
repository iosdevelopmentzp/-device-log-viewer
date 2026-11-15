import Foundation

public struct LogLevel: Hashable, Sendable, Comparable {

    public let index: Int

    public init(index: Int) {
        self.index = index
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.index < rhs.index
    }
}
