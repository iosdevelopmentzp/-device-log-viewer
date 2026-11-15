import Foundation

struct TimestampParser: Sendable {

    enum Field: Sendable {
        case year
        case month
        case day
        case hour
        case minute
        case second
        case fraction
        case literal(UInt8)
    }

    struct Step: Sendable {
        let field: Field
        let length: Int
    }

    let steps: [Step]
    let width: Int
    let zone: ZoneOffset

    private static let space = UInt8(ascii: " ")

    static func compile(_ format: String) -> [Step]? {
        var steps: [Step] = []
        let bytes = Array(format.utf8)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            var length = 1
            while index + length < bytes.count, bytes[index + length] == byte {
                length += 1
            }
            switch byte {
            case UInt8(ascii: "y"): steps.append(Step(field: .year, length: length))
            case UInt8(ascii: "M"): steps.append(Step(field: .month, length: length))
            case UInt8(ascii: "d"): steps.append(Step(field: .day, length: length))
            case UInt8(ascii: "H"): steps.append(Step(field: .hour, length: length))
            case UInt8(ascii: "m"): steps.append(Step(field: .minute, length: length))
            case UInt8(ascii: "s"): steps.append(Step(field: .second, length: length))
            case UInt8(ascii: "S"): steps.append(Step(field: .fraction, length: length))
            default:
                guard byte < 0x80, byte.isLetter == false else { return nil }
                for _ in 0..<length {
                    steps.append(Step(field: .literal(byte), length: 1))
                }
            }
            index += length
        }
        guard steps.contains(where: { if case .literal = $0.field { false } else { true } }) else { return nil }
        return steps
    }

    init?(rule: TimestampRule) {
        guard rule.kind == .pattern, let format = rule.format, let steps = Self.compile(format) else { return nil }
        self.steps = steps
        self.width = steps.reduce(0) { $0 + $1.length }
        self.zone = ZoneOffset(identifier: rule.timeZone)
    }

    func parse(_ bytes: UnsafeRawBufferPointer, at start: Int, end: Int) -> TimeInterval? {
        guard start + width <= end else { return nil }
        var position = start
        var year = 1970
        var month = 1
        var day = 1
        var hour = 0
        var minute = 0
        var second = 0
        var fraction: TimeInterval = 0
        for step in steps {
            switch step.field {
            case .literal(let expected):
                guard bytes[position] == expected else { return nil }
            case .year:
                guard let value = Self.number(bytes, position, step.length) else { return nil }
                year = step.length == 2 ? 2_000 + value : value
            case .month:
                guard let value = Self.number(bytes, position, step.length), (1...12).contains(value) else { return nil }
                month = value
            case .day:
                guard let value = Self.number(bytes, position, step.length), (1...31).contains(value) else { return nil }
                day = value
            case .hour:
                guard let value = Self.number(bytes, position, step.length), value < 24 else { return nil }
                hour = value
            case .minute:
                guard let value = Self.number(bytes, position, step.length), value < 60 else { return nil }
                minute = value
            case .second:
                guard let value = Self.number(bytes, position, step.length), value < 61 else { return nil }
                second = value
            case .fraction:
                guard let value = Self.number(bytes, position, step.length) else { return nil }
                fraction = TimeInterval(value) / pow(10, TimeInterval(step.length))
            }
            position += step.length
        }
        let local = Self.epoch(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return TimeInterval(local - zone.secondsFromGMT(forLocal: local)) + fraction
    }

    static func number(_ bytes: UnsafeRawBufferPointer, _ start: Int, _ length: Int) -> Int? {
        var value = 0
        for index in start..<(start + length) {
            let byte = bytes[index]
            guard byte.isDigit else { return nil }
            value = value * 10 + Int(byte - UInt8(ascii: "0"))
        }
        return value
    }

    static func epoch(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Int {
        daysFromCivil(year: year, month: month, day: day) * 86_400 + hour * 3_600 + minute * 60 + second
    }

    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let shiftedMonth = (month + 9) % 12
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
