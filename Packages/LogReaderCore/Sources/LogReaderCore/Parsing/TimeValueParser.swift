import Foundation

struct TimeValueParser: Sendable {

    private let rule: TimestampRule
    private let pattern: TimestampParser?
    private let zone: ZoneOffset

    var fixedWidth: Int? {
        pattern?.width
    }

    init(rule: TimestampRule) {
        self.rule = rule
        self.pattern = TimestampParser(rule: rule)
        self.zone = ZoneOffset(identifier: rule.timeZone)
    }

    func parse(_ bytes: UnsafeRawBufferPointer, range: Range<Int>) -> TimeInterval? {
        switch rule.kind {
        case .pattern:
            guard let pattern, range.count == pattern.width else { return nil }
            return pattern.parse(bytes, at: range.lowerBound, end: range.upperBound)
        case .iso8601:
            return Self.iso8601(bytes, range: range, zone: zone) ?? Self.epochNumber(bytes, range: range, milliseconds: nil)
        case .epochSeconds:
            return Self.epochNumber(bytes, range: range, milliseconds: false)
        case .epochMilliseconds:
            return Self.epochNumber(bytes, range: range, milliseconds: true)
        }
    }

    func parse(_ text: String) -> TimeInterval? {
        var bytes = Array(text.utf8)
        return bytes.withUnsafeMutableBytes { buffer in
            parse(UnsafeRawBufferPointer(buffer), range: 0..<buffer.count)
        }
    }
}

// MARK: - Private

private extension TimeValueParser {

    static let autoMillisecondsThreshold: TimeInterval = 100_000_000_000

    static func iso8601(_ bytes: UnsafeRawBufferPointer, range: Range<Int>, zone: ZoneOffset) -> TimeInterval? {
        guard range.count >= 19 else { return nil }
        let start = range.lowerBound
        guard bytes[start + 4] == UInt8(ascii: "-"), bytes[start + 7] == UInt8(ascii: "-"),
              bytes[start + 10] == UInt8(ascii: "T") || bytes[start + 10] == .space,
              bytes[start + 13] == UInt8(ascii: ":"), bytes[start + 16] == UInt8(ascii: ":") else { return nil }
        guard let year = TimestampParser.number(bytes, start, 4),
              let month = TimestampParser.number(bytes, start + 5, 2), (1...12).contains(month),
              let day = TimestampParser.number(bytes, start + 8, 2), (1...31).contains(day),
              let hour = TimestampParser.number(bytes, start + 11, 2), hour < 24,
              let minute = TimestampParser.number(bytes, start + 14, 2), minute < 60,
              let second = TimestampParser.number(bytes, start + 17, 2), second < 61 else { return nil }
        var position = start + 19
        var fraction: TimeInterval = 0
        if position < range.upperBound, bytes[position] == UInt8(ascii: ".") || bytes[position] == UInt8(ascii: ",") {
            position += 1
            var digits = 0
            var value = 0
            while position < range.upperBound, bytes[position].isDigit {
                if digits < 9 {
                    value = value * 10 + Int(bytes[position] - UInt8(ascii: "0"))
                    digits += 1
                }
                position += 1
            }
            fraction = TimeInterval(value) / pow(10, TimeInterval(digits))
        }
        let local = TimestampParser.epoch(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard position < range.upperBound else {
            return TimeInterval(local - zone.secondsFromGMT(forLocal: local)) + fraction
        }
        if bytes[position] == UInt8(ascii: "Z") {
            guard position + 1 == range.upperBound else { return nil }
            return TimeInterval(local) + fraction
        }
        guard let offset = zoneOffset(bytes, from: position, to: range.upperBound) else { return nil }
        return TimeInterval(local - offset) + fraction
    }

    static func zoneOffset(_ bytes: UnsafeRawBufferPointer, from start: Int, to end: Int) -> Int? {
        let sign: Int
        switch bytes[start] {
        case UInt8(ascii: "+"): sign = 1
        case UInt8(ascii: "-"): sign = -1
        default: return nil
        }
        guard let hours = TimestampParser.number(bytes, start + 1, min(2, end - start - 1)), end - start >= 3 else { return nil }
        var minutes = 0
        var position = start + 3
        if position < end, bytes[position] == UInt8(ascii: ":") {
            position += 1
        }
        if position < end {
            guard end - position == 2, let value = TimestampParser.number(bytes, position, 2) else { return nil }
            minutes = value
        }
        return sign * (hours * 3_600 + minutes * 60)
    }

    static func epochNumber(_ bytes: UnsafeRawBufferPointer, range: Range<Int>, milliseconds: Bool?) -> TimeInterval? {
        guard range.isEmpty == false else { return nil }
        var value: TimeInterval = 0
        var fractionScale: TimeInterval = 0
        for index in range {
            let byte = bytes[index]
            if byte == UInt8(ascii: ".") {
                guard fractionScale == 0 else { return nil }
                fractionScale = 1
            } else if byte.isDigit {
                if fractionScale == 0 {
                    value = value * 10 + TimeInterval(byte - UInt8(ascii: "0"))
                } else {
                    fractionScale /= 10
                    value += TimeInterval(byte - UInt8(ascii: "0")) * fractionScale
                }
            } else {
                return nil
            }
        }
        let isMilliseconds = milliseconds ?? (value >= autoMillisecondsThreshold)
        return isMilliseconds ? value / 1_000 : value
    }
}
