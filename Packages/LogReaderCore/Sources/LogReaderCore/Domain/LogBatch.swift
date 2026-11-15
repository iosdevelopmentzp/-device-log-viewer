import Foundation

public struct LogBatch: Sendable {
    public let chunkIndex: Int
    public let chunk: Data
    public let records: [LogRecord]
}
