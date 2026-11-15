import Foundation

public struct LogEntryText: Sendable {

    struct Parts {
        let leadingLines: Range<Int>
        let message: Range<Int>
        let body: Range<Int>
    }

    private let grammar: LogEntryGrammar
    private let fieldIndentation: String

    private static let maxHeaderSearchLines = 64

    public init(profile: LogProfile) {
        self.grammar = LogEntryGrammar(profile: profile)
        self.fieldIndentation = String(repeating: " ", count: profile.fields.indent)
    }

    public func messageAndBody(_ bytes: UnsafeRawBufferPointer, record: LogRecord) -> (message: String, body: String) {
        if record.isStructured, let entry = grammar.jsonParser?.parse(bytes, range: 0..<bytes.count, maxFields: Int.max) {
            let body = entry.fields.map { "\(fieldIndentation)\($0.key): \($0.value)" }
            return (entry.message, body.joined(separator: "\n"))
        }
        let parts = parts(bytes, record: record)
        return (Self.string(bytes, parts.leadingLines) + Self.string(bytes, parts.message), Self.string(bytes, parts.body))
    }

    public func wrappedLineCount(_ bytes: UnsafeRawBufferPointer, record: LogRecord, columns: Int, maxLines: Int) -> Int {
        if record.isStructured, grammar.jsonParser != nil {
            let text = messageAndBody(bytes, record: record)
            let joined = text.body.isEmpty ? text.message : text.message + "\n" + text.body
            return LogTextMetrics.wrappedLineCount(joined, columns: columns, maxLines: maxLines)
        }
        let parts = parts(bytes, record: record)
        var counter = WrappedLineCounter(columns: columns, maxLines: maxLines)
        counter.consume(UnsafeRawBufferPointer(rebasing: bytes[parts.leadingLines]))
        counter.consume(UnsafeRawBufferPointer(rebasing: bytes[parts.message]))
        if parts.body.isEmpty == false {
            counter.consume(LogFileFormat.newline)
            counter.consume(UnsafeRawBufferPointer(rebasing: bytes[parts.body]))
        }
        return counter.lineCount
    }
}

// MARK: - Private

private extension LogEntryText {

    func parts(_ bytes: UnsafeRawBufferPointer, record: LogRecord) -> Parts {
        let end = bytes.count
        if record.isStructured {
            var lineStart = 0
            for _ in 0..<Self.maxHeaderSearchLines {
                let lineEnd = ByteScan.index(of: LogFileFormat.newline, in: bytes, from: lineStart, to: end) ?? end
                if let header = grammar.headerLine(bytes, lineStart: lineStart, lineEnd: lineEnd) {
                    return Parts(
                        leadingLines: 0..<lineStart,
                        message: header.messageRange.clamped(to: lineStart..<lineEnd),
                        body: min(lineEnd + 1, end)..<end
                    )
                }
                guard lineEnd < end else { break }
                lineStart = lineEnd + 1
            }
        }
        let firstLineEnd = ByteScan.index(of: LogFileFormat.newline, in: bytes, from: 0, to: end) ?? end
        return Parts(leadingLines: 0..<0, message: 0..<firstLineEnd, body: min(firstLineEnd + 1, end)..<end)
    }

    static func string(_ bytes: UnsafeRawBufferPointer, _ range: Range<Int>) -> String {
        String(decoding: UnsafeRawBufferPointer(rebasing: bytes[range]), as: UTF8.self)
    }
}
