import Foundation

struct LevelMatcher: Sendable {

    private struct Code: Sendable {
        let bytes: [UInt8]
        let level: LogLevel
    }

    private let codes: [Code]
    private let lengths: Set<Int>

    init(levels: [LevelRule]) {
        var codes: [Code] = []
        for (index, level) in levels.enumerated() {
            for code in level.codes where code.isEmpty == false {
                codes.append(Code(bytes: Array(code.utf8), level: LogLevel(index: index)))
            }
        }
        self.codes = codes
        self.lengths = Set(codes.map(\.bytes.count))
    }

    func level(_ bytes: UnsafeRawBufferPointer, range: Range<Int>) -> LogLevel? {
        guard lengths.contains(range.count) else { return nil }
        for code in codes where code.bytes.count == range.count {
            var matches = true
            for (offset, byte) in code.bytes.enumerated() where bytes[range.lowerBound + offset] != byte {
                matches = false
                break
            }
            if matches { return code.level }
        }
        return nil
    }

    func level(_ text: String) -> LogLevel? {
        var bytes = Array(text.utf8)
        return bytes.withUnsafeMutableBytes { buffer in
            level(UnsafeRawBufferPointer(buffer), range: 0..<buffer.count)
        }
    }
}
