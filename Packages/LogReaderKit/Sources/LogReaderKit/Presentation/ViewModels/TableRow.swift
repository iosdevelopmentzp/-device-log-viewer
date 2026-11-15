import Foundation

enum TableRow: Equatable {
    case single(recordIndex: Int)
    case group(firstRecordIndex: Int, recordIndices: [Int], isExpanded: Bool)
    case member(recordIndex: Int, firstRecordIndex: Int)
}
