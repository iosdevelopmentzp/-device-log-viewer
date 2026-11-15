import Foundation

extension RowCollapser {

    struct AppendResult: Equatable {
        let insertedRows: Range<Int>
        let changedRow: Int?
    }
}
