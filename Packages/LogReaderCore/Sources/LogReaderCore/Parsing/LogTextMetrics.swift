import Foundation

public enum LogTextMetrics {

    public static func wrappedLineCount(_ bytes: UnsafeRawBufferPointer, columns: Int, maxLines: Int) -> Int {
        var counter = WrappedLineCounter(columns: columns, maxLines: maxLines)
        counter.consume(bytes)
        return counter.lineCount
    }

    public static func wrappedLineCount(_ text: String, columns: Int, maxLines: Int) -> Int {
        var text = text
        return text.withUTF8 { wrappedLineCount(UnsafeRawBufferPointer($0), columns: columns, maxLines: maxLines) }
    }

    public static func drawableText(_ text: String) -> String {
        guard text.utf8.contains(where: { $0 == UInt8(ascii: "\r") || $0 == UInt8(ascii: "\t") }) else { return text }
        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: String(repeating: " ", count: WrappedLineCounter.tabWidth))
    }

    public static func wrappedLineRanges(ofDrawableText text: String, columns: Int, maxLines: Int) -> [NSRange] {
        var text = text
        var ranges: [NSRange] = []
        text.withUTF8 { buffer in
            forEachWrappedLine(UnsafeRawBufferPointer(buffer), columns: columns) { range in
                ranges.append(range)
                return ranges.count < maxLines
            }
        }
        return ranges
    }
}

// MARK: - Private

private extension LogTextMetrics {

    static let fourByteLead: UInt8 = 0xF0

    static func forEachWrappedLine(_ bytes: UnsafeRawBufferPointer, columns: Int, _ body: (NSRange) -> Bool) {
        let columns = max(columns, 1)
        var lineStart = 0
        var position = 0
        var characters = 0
        for byte in bytes {
            if byte == LogFileFormat.newline {
                guard body(NSRange(location: lineStart, length: position - lineStart)) else { return }
                position += 1
                lineStart = position
                characters = 0
                continue
            }
            guard byte & 0xC0 != 0x80 else { continue }
            if characters == columns {
                guard body(NSRange(location: lineStart, length: position - lineStart)) else { return }
                lineStart = position
                characters = 0
            }
            characters += 1
            position += byte >= fourByteLead ? 2 : 1
        }
        _ = body(NSRange(location: lineStart, length: position - lineStart))
    }
}
