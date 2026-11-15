import Foundation

extension UInt8 {

    static let space = UInt8(ascii: " ")
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")

    var isDigit: Bool {
        self >= UInt8(ascii: "0") && self <= UInt8(ascii: "9")
    }

    var isLetter: Bool {
        (self >= UInt8(ascii: "a") && self <= UInt8(ascii: "z")) || (self >= UInt8(ascii: "A") && self <= UInt8(ascii: "Z"))
    }

    var isLineBreak: Bool {
        self == .newline || self == .carriageReturn
    }
}
