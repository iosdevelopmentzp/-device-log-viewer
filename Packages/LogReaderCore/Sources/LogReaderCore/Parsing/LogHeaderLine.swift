import Foundation

struct LogHeaderLine {
    let level: LogLevel?
    let timestamp: TimeInterval?
    let attributes: [AttributeValue]
    let messageRange: Range<Int>
    let metadataRange: Range<Int>
}
