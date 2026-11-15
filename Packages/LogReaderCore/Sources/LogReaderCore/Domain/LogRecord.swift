import Foundation

public struct LogRecord: Sendable, Hashable {
    public let offset: Int
    public let chunk: Int
    public let start: Int
    public let length: Int
    public let metadataRange: Range<Int>
    public let level: LogLevel?
    public let timestamp: TimeInterval?
    public let message: String
    public let detailPreview: String
    public let attributes: [AttributeValue]
    public let isStructured: Bool

    public init(
        offset: Int,
        chunk: Int,
        start: Int,
        length: Int,
        metadataRange: Range<Int>,
        level: LogLevel?,
        timestamp: TimeInterval?,
        message: String,
        detailPreview: String,
        attributes: [AttributeValue],
        isStructured: Bool
    ) {
        self.offset = offset
        self.chunk = chunk
        self.start = start
        self.length = length
        self.metadataRange = metadataRange
        self.level = level
        self.timestamp = timestamp
        self.message = message
        self.detailPreview = detailPreview
        self.attributes = attributes
        self.isStructured = isStructured
    }
}
