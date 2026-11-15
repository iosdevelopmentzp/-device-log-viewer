import Foundation

enum JSONLineScanner {

    struct Member {
        let key: String
        let value: Value
    }

    enum Value {
        case string(String)
        case scalar(String)
        case nested(Range<Int>)

        var isNested: Bool {
            guard case .nested = self else { return false }
            return true
        }

        func text(in bytes: UnsafeRawBufferPointer) -> String {
            switch self {
            case .string(let value), .scalar(let value): value
            case .nested(let range): JSONLineScanner.string(bytes, range: range)
            }
        }
    }

    static func members(_ bytes: UnsafeRawBufferPointer, range: Range<Int>) -> [Member]? {
        var position = skippingWhitespace(bytes, from: range.lowerBound, to: range.upperBound)
        guard position < range.upperBound, bytes[position] == UInt8(ascii: "{") else { return nil }
        position += 1
        var members: [Member] = []
        while true {
            position = skippingWhitespace(bytes, from: position, to: range.upperBound)
            guard position < range.upperBound else { return nil }
            if bytes[position] == UInt8(ascii: "}") {
                return members
            }
            guard let keyEnd = stringEnd(bytes, from: position, to: range.upperBound) else { return nil }
            let key = decodeString(bytes, range: (position + 1)..<keyEnd)
            position = skippingWhitespace(bytes, from: keyEnd + 1, to: range.upperBound)
            guard position < range.upperBound, bytes[position] == UInt8(ascii: ":") else { return nil }
            position = skippingWhitespace(bytes, from: position + 1, to: range.upperBound)
            guard let (value, valueEnd) = value(bytes, from: position, to: range.upperBound) else { return nil }
            members.append(Member(key: key, value: value))
            position = skippingWhitespace(bytes, from: valueEnd, to: range.upperBound)
            guard position < range.upperBound else { return nil }
            if bytes[position] == UInt8(ascii: ",") {
                position += 1
            } else if bytes[position] != UInt8(ascii: "}") {
                return nil
            }
        }
    }

    static func stringItems(_ text: String) -> [String]? {
        var bytes = Array(text.utf8)
        return bytes.withUnsafeMutableBytes { buffer -> [String]? in
            let bytes = UnsafeRawBufferPointer(buffer)
            var position = skippingWhitespace(bytes, from: 0, to: bytes.count)
            guard position < bytes.count, bytes[position] == UInt8(ascii: "[") else { return nil }
            position += 1
            var items: [String] = []
            while true {
                position = skippingWhitespace(bytes, from: position, to: bytes.count)
                guard position < bytes.count else { return nil }
                if bytes[position] == UInt8(ascii: "]") { return items }
                guard let (value, valueEnd) = value(bytes, from: position, to: bytes.count) else { return nil }
                items.append(value.text(in: bytes))
                position = skippingWhitespace(bytes, from: valueEnd, to: bytes.count)
                guard position < bytes.count else { return nil }
                if bytes[position] == UInt8(ascii: ",") {
                    position += 1
                } else if bytes[position] != UInt8(ascii: "]") {
                    return nil
                }
            }
        }
    }
}

// MARK: - Private

private extension JSONLineScanner {

    static func value(_ bytes: UnsafeRawBufferPointer, from start: Int, to end: Int) -> (Value, Int)? {
        guard start < end else { return nil }
        switch bytes[start] {
        case UInt8(ascii: "\""):
            guard let stringEnd = stringEnd(bytes, from: start, to: end) else { return nil }
            return (.string(decodeString(bytes, range: (start + 1)..<stringEnd)), stringEnd + 1)
        case UInt8(ascii: "{"), UInt8(ascii: "["):
            guard let nestedEnd = nestedEnd(bytes, from: start, to: end) else { return nil }
            return (.nested(start..<nestedEnd), nestedEnd)
        default:
            var position = start
            while position < end, isScalarByte(bytes[position]) {
                position += 1
            }
            guard position > start else { return nil }
            return (.scalar(string(bytes, range: start..<position)), position)
        }
    }

    static func isScalarByte(_ byte: UInt8) -> Bool {
        byte.isDigit || byte.isLetter || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+") || byte == UInt8(ascii: ".")
    }

    static func stringEnd(_ bytes: UnsafeRawBufferPointer, from start: Int, to end: Int) -> Int? {
        guard start < end, bytes[start] == UInt8(ascii: "\"") else { return nil }
        var position = start + 1
        while position < end {
            switch bytes[position] {
            case UInt8(ascii: "\\"): position += 2
            case UInt8(ascii: "\""): return position
            default: position += 1
            }
        }
        return nil
    }

    static func nestedEnd(_ bytes: UnsafeRawBufferPointer, from start: Int, to end: Int) -> Int? {
        var depth = 0
        var position = start
        while position < end {
            switch bytes[position] {
            case UInt8(ascii: "\""):
                guard let stringEnd = stringEnd(bytes, from: position, to: end) else { return nil }
                position = stringEnd
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                depth += 1
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                depth -= 1
                if depth == 0 { return position + 1 }
            default:
                break
            }
            position += 1
        }
        return nil
    }

    static func skippingWhitespace(_ bytes: UnsafeRawBufferPointer, from start: Int, to end: Int) -> Int {
        var position = start
        while position < end, bytes[position] == .space || bytes[position] == UInt8(ascii: "\t") || bytes[position].isLineBreak {
            position += 1
        }
        return position
    }

    static func decodeString(_ bytes: UnsafeRawBufferPointer, range: Range<Int>) -> String {
        guard ByteScan.index(of: UInt8(ascii: "\\"), in: bytes, from: range.lowerBound, to: range.upperBound) != nil else {
            return string(bytes, range: range)
        }
        var result: [UInt8] = []
        result.reserveCapacity(range.count)
        var position = range.lowerBound
        while position < range.upperBound {
            let byte = bytes[position]
            guard byte == UInt8(ascii: "\\"), position + 1 < range.upperBound else {
                result.append(byte)
                position += 1
                continue
            }
            let escaped = bytes[position + 1]
            position += 2
            switch escaped {
            case UInt8(ascii: "n"): result.append(.newline)
            case UInt8(ascii: "t"): result.append(UInt8(ascii: "\t"))
            case UInt8(ascii: "r"): result.append(.carriageReturn)
            case UInt8(ascii: "b"): result.append(0x08)
            case UInt8(ascii: "f"): result.append(0x0C)
            case UInt8(ascii: "u"):
                guard let scalar = unicodeScalar(bytes, at: &position, end: range.upperBound) else { continue }
                result.append(contentsOf: Array(String(Character(scalar)).utf8))
            default: result.append(escaped)
            }
        }
        return String(decoding: result, as: UTF8.self)
    }

    static func unicodeScalar(_ bytes: UnsafeRawBufferPointer, at position: inout Int, end: Int) -> Unicode.Scalar? {
        guard let first = hex(bytes, at: position, end: end) else { return nil }
        position += 4
        guard UTF16.isLeadSurrogate(UInt16(first)) else { return Unicode.Scalar(first) }
        guard position + 6 <= end, bytes[position] == UInt8(ascii: "\\"), bytes[position + 1] == UInt8(ascii: "u"),
              let second = hex(bytes, at: position + 2, end: end), UTF16.isTrailSurrogate(UInt16(second)) else { return nil }
        position += 6
        return UTF16.decode(UTF16.EncodedScalar([UInt16(first), UInt16(second)]))
    }

    static func hex(_ bytes: UnsafeRawBufferPointer, at start: Int, end: Int) -> UInt32? {
        guard start + 4 <= end else { return nil }
        var value: UInt32 = 0
        for index in start..<(start + 4) {
            let byte = bytes[index]
            let digit: UInt32
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = UInt32(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = UInt32(byte - UInt8(ascii: "a") + 10)
            case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = UInt32(byte - UInt8(ascii: "A") + 10)
            default: return nil
            }
            value = value * 16 + digit
        }
        return value
    }

}

extension JSONLineScanner {

    static func string(_ bytes: UnsafeRawBufferPointer, range: Range<Int>) -> String {
        String(decoding: UnsafeRawBufferPointer(rebasing: bytes[range]), as: UTF8.self)
    }
}
