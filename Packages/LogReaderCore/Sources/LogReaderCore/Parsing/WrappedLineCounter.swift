import Foundation

struct WrappedLineCounter {

    private let columns: Int
    private let maxLines: Int
    private var completedLines = 0
    private var characters = 0
    private var isAfterCarriageReturn = false

    var isFull: Bool { completedLines >= maxLines }

    var lineCount: Int { min(completedLines + 1, maxLines) }

    static let tabWidth = 4
    private static let carriageReturn = UInt8(ascii: "\r")
    private static let tab = UInt8(ascii: "\t")

    init(columns: Int, maxLines: Int) {
        self.columns = max(columns, 1)
        self.maxLines = max(maxLines, 1)
    }

    mutating func consume(_ bytes: UnsafeRawBufferPointer) {
        for byte in bytes {
            guard isFull == false else { return }
            consume(byte)
        }
    }

    mutating func consume(_ byte: UInt8) {
        switch byte {
        case LogFileFormat.newline:
            if isAfterCarriageReturn == false {
                endLine()
            }
            isAfterCarriageReturn = false
        case Self.carriageReturn:
            endLine()
            isAfterCarriageReturn = true
        case Self.tab:
            isAfterCarriageReturn = false
            for _ in 0..<Self.tabWidth {
                addCharacter()
            }
        default:
            isAfterCarriageReturn = false
            if byte & 0xC0 != 0x80 {
                addCharacter()
            }
        }
    }
}

// MARK: - Private

private extension WrappedLineCounter {

    mutating func endLine() {
        completedLines += 1
        characters = 0
    }

    mutating func addCharacter() {
        if characters == columns {
            endLine()
        }
        characters += 1
    }
}
