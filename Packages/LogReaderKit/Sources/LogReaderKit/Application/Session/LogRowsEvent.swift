import Foundation

public enum LogRowsEvent: Sendable, Equatable {
    case reload
    case inserted(Range<Int>)
    case refreshRows
    case select(row: Int)
    case scrollToEnd
}
