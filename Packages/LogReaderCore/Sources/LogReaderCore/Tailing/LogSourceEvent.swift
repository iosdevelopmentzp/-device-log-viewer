import Foundation

public enum LogSourceEvent: Sendable {
    case batch(LogBatch)
    case reset
    case missing
}
