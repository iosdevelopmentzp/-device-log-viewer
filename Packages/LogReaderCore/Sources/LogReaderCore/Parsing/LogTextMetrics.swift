import Foundation

public enum LogTextMetrics {

    public static func wrappedLineCount(_ bytes: UnsafeRawBufferPointer, columns: Int, maxLines: Int) -> Int {
        let columns = max(columns, 1)
        var lines = 0
        var characters = 0
        for byte in bytes {
            if byte == LogFileFormat.newline {
                lines += visualLines(characters: characters, columns: columns)
                guard lines < maxLines else { return maxLines }
                characters = 0
            } else if byte & 0xC0 != 0x80 {
                characters += 1
            }
        }
        lines += visualLines(characters: characters, columns: columns)
        return min(lines, maxLines)
    }
}

// MARK: - Private

private extension LogTextMetrics {

    static func visualLines(characters: Int, columns: Int) -> Int {
        max(1, (characters + columns - 1) / columns)
    }
}
