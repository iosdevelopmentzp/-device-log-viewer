import Foundation

public struct LogContent: Sendable {

    public let profile: LogProfile
    public private(set) var chunks: [Data] = []
    public private(set) var records: [LogRecord] = []

    public var totalBytes: Int { chunks.reduce(0) { $0 + $1.count } }

    public init(profile: LogProfile) {
        self.profile = profile
    }

    @discardableResult
    public mutating func append(_ batch: LogBatch) -> Range<Int> {
        precondition(batch.chunkIndex == chunks.count, "Batch chunk index does not match stored chunks")
        chunks.append(batch.chunk)
        let lower = records.count
        records.append(contentsOf: batch.records)
        return lower..<records.count
    }

    public func text(of record: LogRecord) -> String {
        withBytes(of: record) { String(decoding: $0, as: UTF8.self) }
    }

    public func withBytes<Result>(of record: LogRecord, _ body: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
        try chunks[record.chunk].withUnsafeBytes { bytes in
            try body(UnsafeRawBufferPointer(rebasing: bytes[record.start..<(record.start + record.length)]))
        }
    }
}
