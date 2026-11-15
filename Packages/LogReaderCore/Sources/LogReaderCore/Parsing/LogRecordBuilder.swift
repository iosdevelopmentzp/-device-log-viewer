import Foundation

enum LogRecordBuilder {

    private static let maxHeaderSearchLines = 64
    private static let maxMessageBytes = 1_024
    private static let maxPreviewBytes = 240

    static func records(
        in chunk: Data,
        chunkIndex: Int,
        baseOffset: Int,
        format: LogFileFormat,
        grammar: LogEntryGrammar,
        joinsUnrecognizedLines: Bool
    ) -> [LogRecord] {
        chunk.withUnsafeBytes { bytes in
            var records: [LogRecord] = []
            records.reserveCapacity(bytes.count / 256)
            let terminator = format.terminator
            var start = 0
            while start < bytes.count {
                let end = ByteScan.index(of: terminator, in: bytes, from: start, to: bytes.count) ?? bytes.count
                let entry = trimmed(bytes, start: start, end: end)
                if entry.isEmpty == false {
                    let record = makeRecord(bytes, entry: entry, chunkIndex: chunkIndex, baseOffset: baseOffset, grammar: grammar)
                    if joinsUnrecognizedLines, record.isStructured == false, let last = records.last {
                        let merged = last.start..<entry.upperBound
                        records[records.count - 1] = makeRecord(bytes, entry: merged, chunkIndex: chunkIndex, baseOffset: baseOffset, grammar: grammar)
                    } else {
                        records.append(record)
                    }
                }
                start = end + 1
            }
            return records
        }
    }
}

// MARK: - Private

private extension LogRecordBuilder {

    static func trimmed(_ bytes: UnsafeRawBufferPointer, start: Int, end: Int) -> Range<Int> {
        var lower = start
        var upper = end
        while upper > lower, bytes[upper - 1].isLineBreak {
            upper -= 1
        }
        while lower < upper, bytes[lower].isLineBreak {
            lower += 1
        }
        return lower..<upper
    }

    static func makeRecord(
        _ bytes: UnsafeRawBufferPointer,
        entry: Range<Int>,
        chunkIndex: Int,
        baseOffset: Int,
        grammar: LogEntryGrammar
    ) -> LogRecord {
        if let parser = grammar.jsonParser {
            return makeJSONRecord(bytes, entry: entry, chunkIndex: chunkIndex, baseOffset: baseOffset, parser: parser)
        }
        var lineStart = entry.lowerBound
        var lineIndex = 0
        while lineStart < entry.upperBound, lineIndex < maxHeaderSearchLines {
            let lineEnd = ByteScan.index(of: .newline, in: bytes, from: lineStart, to: entry.upperBound) ?? entry.upperBound
            if let header = grammar.headerLine(bytes, lineStart: lineStart, lineEnd: lineEnd) {
                let messageRange = header.messageRange.lowerBound == lineStart
                    ? entry.lowerBound..<header.messageRange.upperBound
                    : header.messageRange
                return LogRecord(
                    offset: baseOffset + entry.lowerBound,
                    chunk: chunkIndex,
                    start: entry.lowerBound,
                    length: entry.count,
                    metadataRange: (header.metadataRange.lowerBound - entry.lowerBound)..<(header.metadataRange.upperBound - entry.lowerBound),
                    level: header.level,
                    timestamp: header.timestamp,
                    message: summary(bytes, range: messageRange),
                    detailPreview: preview(bytes, from: lineEnd + 1, to: entry.upperBound),
                    attributes: header.attributes,
                    isStructured: true
                )
            }
            lineStart = lineEnd + 1
            lineIndex += 1
        }
        return unstructuredRecord(bytes, entry: entry, chunkIndex: chunkIndex, baseOffset: baseOffset, attributeCount: grammar.attributeCount)
    }

    static func makeJSONRecord(
        _ bytes: UnsafeRawBufferPointer,
        entry: Range<Int>,
        chunkIndex: Int,
        baseOffset: Int,
        parser: JSONEntryParser
    ) -> LogRecord {
        guard let parsed = parser.parse(bytes, range: entry, maxFields: 1) else {
            return unstructuredRecord(bytes, entry: entry, chunkIndex: chunkIndex, baseOffset: baseOffset, attributeCount: parser.attributeCount)
        }
        let firstField = parsed.fields.first.map { "\($0.key): \($0.value)" } ?? ""
        return LogRecord(
            offset: baseOffset + entry.lowerBound,
            chunk: chunkIndex,
            start: entry.lowerBound,
            length: entry.count,
            metadataRange: 0..<0,
            level: parsed.level,
            timestamp: parsed.timestamp,
            message: summary(parsed.message),
            detailPreview: String(decoding: Array(firstField.utf8.prefix(maxPreviewBytes)), as: UTF8.self),
            attributes: parsed.attributes,
            isStructured: true
        )
    }

    static func unstructuredRecord(
        _ bytes: UnsafeRawBufferPointer,
        entry: Range<Int>,
        chunkIndex: Int,
        baseOffset: Int,
        attributeCount: Int
    ) -> LogRecord {
        let firstLineEnd = ByteScan.index(of: .newline, in: bytes, from: entry.lowerBound, to: entry.upperBound) ?? entry.upperBound
        return LogRecord(
            offset: baseOffset + entry.lowerBound,
            chunk: chunkIndex,
            start: entry.lowerBound,
            length: entry.count,
            metadataRange: 0..<0,
            level: nil,
            timestamp: nil,
            message: summary(bytes, range: entry.lowerBound..<firstLineEnd),
            detailPreview: preview(bytes, from: firstLineEnd + 1, to: entry.upperBound),
            attributes: Array(repeating: .none, count: attributeCount),
            isStructured: false
        )
    }

    static func summary(_ bytes: UnsafeRawBufferPointer, range: Range<Int>) -> String {
        guard range.isEmpty == false else { return "" }
        let upper = min(range.upperBound, range.lowerBound + maxMessageBytes)
        let text = String(decoding: UnsafeRawBufferPointer(rebasing: bytes[range.lowerBound..<upper]), as: UTF8.self)
        guard ByteScan.index(of: .newline, in: bytes, from: range.lowerBound, to: upper) != nil else { return text }
        return text.replacingOccurrences(of: "\n", with: " ⏎ ")
    }

    static func summary(_ message: String) -> String {
        let text = message.utf8.count > maxMessageBytes
            ? String(decoding: Array(message.utf8.prefix(maxMessageBytes)), as: UTF8.self)
            : message
        guard text.contains("\n") else { return text }
        return text.replacingOccurrences(of: "\n", with: " ⏎ ")
    }

    static func preview(_ bytes: UnsafeRawBufferPointer, from start: Int, to end: Int) -> String {
        guard start < end else { return "" }
        var lower = start
        while lower < end, bytes[lower] == .space {
            lower += 1
        }
        let lineEnd = ByteScan.index(of: .newline, in: bytes, from: lower, to: end) ?? end
        let upper = min(lineEnd, lower + maxPreviewBytes)
        guard lower < upper else { return "" }
        return String(decoding: UnsafeRawBufferPointer(rebasing: bytes[lower..<upper]), as: UTF8.self)
    }
}
