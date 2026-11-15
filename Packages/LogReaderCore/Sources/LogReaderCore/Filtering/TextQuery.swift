import Foundation

public struct TextQuery: Sendable {

    private struct RegexBox: @unchecked Sendable {
        let expression: NSRegularExpression
    }

    public let text: String

    private let asciiNeedle: [UInt8]?
    private let regex: RegexBox?

    public var isRegex: Bool { regex != nil }

    public init?(_ text: String) {
        guard text.isEmpty == false else { return nil }
        self.text = text
        let utf8 = Array(text.utf8)
        self.asciiNeedle = utf8.allSatisfy { $0 < 0x80 } ? utf8.map(Self.lowercasedASCII) : nil
        self.regex = nil
    }

    private init(pattern: String, expression: NSRegularExpression) {
        self.text = pattern
        self.asciiNeedle = nil
        self.regex = RegexBox(expression: expression)
    }

    public static func regex(_ pattern: String) throws -> TextQuery {
        let expression = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        return TextQuery(pattern: pattern, expression: expression)
    }

    public func matches(_ bytes: UnsafeRawBufferPointer) -> Bool {
        if let regex {
            return Self.firstMatch(of: regex.expression, in: String(decoding: bytes, as: UTF8.self))
        }
        guard let asciiNeedle else {
            guard Self.containsNonASCII(bytes) else { return false }
            let haystack = String(decoding: bytes, as: UTF8.self)
            return haystack.range(of: text, options: .caseInsensitive) != nil
        }
        return Self.containsASCIICaseInsensitive(bytes, needle: asciiNeedle)
    }

    public func countMatches(in bytes: UnsafeRawBufferPointer) -> Int {
        if let regex {
            let string = String(decoding: bytes, as: UTF8.self)
            return regex.expression.numberOfMatches(in: string, range: NSRange(string.startIndex..., in: string))
        }
        guard let asciiNeedle else {
            guard Self.containsNonASCII(bytes) else { return 0 }
            return ranges(in: String(decoding: bytes, as: UTF8.self)).count
        }
        return Self.countASCIICaseInsensitive(bytes, needle: asciiNeedle)
    }

    public func matches(_ string: String) -> Bool {
        if let regex {
            return Self.firstMatch(of: regex.expression, in: string)
        }
        var copy = string
        return copy.withUTF8 { buffer in matches(UnsafeRawBufferPointer(buffer)) }
    }

    public func ranges(in string: String) -> [Range<String.Index>] {
        if let regex {
            return regex.expression
                .matches(in: string, range: NSRange(string.startIndex..., in: string))
                .compactMap { Range($0.range, in: string) }
                .filter { $0.isEmpty == false }
        }
        var result: [Range<String.Index>] = []
        var searchStart = string.startIndex
        while searchStart < string.endIndex,
              let range = string.range(
                  of: text,
                  options: .caseInsensitive,
                  range: searchStart..<string.endIndex
              ) {
            result.append(range)
            searchStart = range.isEmpty ? string.index(after: range.lowerBound) : range.upperBound
        }
        return result
    }
}

// MARK: - Equatable

extension TextQuery: Equatable {

    public static func == (lhs: TextQuery, rhs: TextQuery) -> Bool {
        lhs.text == rhs.text && lhs.isRegex == rhs.isRegex
    }
}

// MARK: - Private

private extension TextQuery {

    static func firstMatch(of expression: NSRegularExpression, in string: String) -> Bool {
        expression.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
    }

    static func lowercasedASCII(_ byte: UInt8) -> UInt8 {
        byte >= 0x41 && byte <= 0x5A ? byte | 0x20 : byte
    }

    static func containsNonASCII(_ bytes: UnsafeRawBufferPointer) -> Bool {
        guard let base = bytes.baseAddress else { return false }
        let count = bytes.count
        let highBits: UInt64 = 0x8080_8080_8080_8080
        var index = 0
        while index + 8 <= count {
            if base.loadUnaligned(fromByteOffset: index, as: UInt64.self) & highBits != 0 { return true }
            index += 8
        }
        while index < count {
            if bytes[index] >= 0x80 { return true }
            index += 1
        }
        return false
    }

    static func containsASCIICaseInsensitive(_ bytes: UnsafeRawBufferPointer, needle: [UInt8]) -> Bool {
        let count = bytes.count
        let needleCount = needle.count
        guard needleCount <= count, let base = bytes.baseAddress else { return false }
        let first = needle[0]
        let firstUpper = first >= 0x61 && first <= 0x7A ? first & ~0x20 : first
        let lastStart = count - needleCount
        var position = 0
        while position <= lastStart {
            guard let candidate = nextCandidate(base, from: position, through: lastStart, lower: first, upper: firstUpper) else {
                return false
            }
            if matchesTail(bytes, at: candidate, needle: needle) { return true }
            position = candidate + 1
        }
        return false
    }

    static func countASCIICaseInsensitive(_ bytes: UnsafeRawBufferPointer, needle: [UInt8]) -> Int {
        let count = bytes.count
        let needleCount = needle.count
        guard needleCount <= count, let base = bytes.baseAddress else { return 0 }
        let first = needle[0]
        let firstUpper = first >= 0x61 && first <= 0x7A ? first & ~0x20 : first
        let lastStart = count - needleCount
        var position = 0
        var matches = 0
        while position <= lastStart {
            guard let candidate = nextCandidate(base, from: position, through: lastStart, lower: first, upper: firstUpper) else {
                return matches
            }
            if matchesTail(bytes, at: candidate, needle: needle) {
                matches += 1
                position = candidate + needleCount
            } else {
                position = candidate + 1
            }
        }
        return matches
    }

    static func nextCandidate(_ base: UnsafeRawPointer, from position: Int, through lastStart: Int, lower: UInt8, upper: UInt8) -> Int? {
        let length = lastStart - position + 1
        let lowerHit = memchr(base + position, Int32(lower), length).map { base.distance(to: UnsafeRawPointer($0)) }
        guard lower != upper else { return lowerHit }
        let upperHit = memchr(base + position, Int32(upper), length).map { base.distance(to: UnsafeRawPointer($0)) }
        switch (lowerHit, upperHit) {
        case let (lowerIndex?, upperIndex?): return min(lowerIndex, upperIndex)
        case let (lowerIndex?, nil): return lowerIndex
        case let (nil, upperIndex?): return upperIndex
        case (nil, nil): return nil
        }
    }

    static func matchesTail(_ bytes: UnsafeRawBufferPointer, at start: Int, needle: [UInt8]) -> Bool {
        var index = 1
        while index < needle.count {
            guard lowercasedASCII(bytes[start + index]) == needle[index] else { return false }
            index += 1
        }
        return true
    }
}
