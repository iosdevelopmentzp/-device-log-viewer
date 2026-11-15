import Foundation
import Testing
@testable import LogReaderKit

struct RowCollapserTests {

    private let keys = ["a", "a", "b", "c", "c", "c", "d", "d"]

    @Test func consecutiveRecordsWithTheSameKeyFormAGroup() {
        let collapser = makeCollapser(recordIndices: [0, 1, 2, 3, 4, 5])

        #expect(collapser.rows == [
            .group(firstRecordIndex: 0, recordIndices: [0, 1], isExpanded: false),
            .single(recordIndex: 2),
            .group(firstRecordIndex: 3, recordIndices: [3, 4, 5], isExpanded: false)
        ])
        #expect(collapser.rowCount == 3)
        #expect(collapser.row(at: 3) == nil)
        #expect(collapser.recordIndex(atRow: 0) == 0)
        #expect(collapser.recordIndex(atRow: 2) == 3)
        #expect(collapser.recordIndex(atRow: 3) == nil)
    }

    @Test func aSingleRecordIsNotAGroup() {
        let collapser = makeCollapser(recordIndices: [1, 2, 3])

        #expect(collapser.rows == [.single(recordIndex: 1), .single(recordIndex: 2), .single(recordIndex: 3)])
    }

    @Test func appendExtendsASingleIntoAGroup() {
        var collapser = makeCollapser(recordIndices: [2, 3])

        let result = collapser.append(recordIndices: [4], key: key)

        #expect(result == RowCollapser.AppendResult(insertedRows: 2..<2, changedRow: 1))
        #expect(collapser.rows == [
            .single(recordIndex: 2),
            .group(firstRecordIndex: 3, recordIndices: [3, 4], isExpanded: false)
        ])
    }

    @Test func appendGrowsAGroupAndAddsNewRows() {
        var collapser = makeCollapser(recordIndices: [3, 4])

        let result = collapser.append(recordIndices: [5, 6, 7], key: key)

        #expect(result == RowCollapser.AppendResult(insertedRows: 1..<2, changedRow: 0))
        #expect(collapser.rows == [
            .group(firstRecordIndex: 3, recordIndices: [3, 4, 5], isExpanded: false),
            .group(firstRecordIndex: 6, recordIndices: [6, 7], isExpanded: false)
        ])
    }

    @Test func appendWithANewKeyChangesNoRow() {
        var collapser = makeCollapser(recordIndices: [0, 1])

        let result = collapser.append(recordIndices: [2], key: key)

        #expect(result == RowCollapser.AppendResult(insertedRows: 1..<2, changedRow: nil))
    }

    @Test func appendToAnExpandedGroupInsertsAMemberRow() {
        var collapser = makeCollapser(recordIndices: [2, 3, 4])
        let isToggled = collapser.toggleGroup(atRow: 1)
        #expect(isToggled)

        let result = collapser.append(recordIndices: [5], key: key)

        #expect(result == RowCollapser.AppendResult(insertedRows: 3..<4, changedRow: 1))
        #expect(collapser.rows == [
            .single(recordIndex: 2),
            .group(firstRecordIndex: 3, recordIndices: [3, 4, 5], isExpanded: true),
            .member(recordIndex: 4, firstRecordIndex: 3),
            .member(recordIndex: 5, firstRecordIndex: 3)
        ])
    }

    @Test func toggleGroupShowsAndHidesTheMembers() {
        var collapser = makeCollapser(recordIndices: [0, 1, 2])

        let isExpanded = collapser.toggleGroup(atRow: 0)

        #expect(isExpanded)
        #expect(collapser.rows == [
            .group(firstRecordIndex: 0, recordIndices: [0, 1], isExpanded: true),
            .member(recordIndex: 1, firstRecordIndex: 0),
            .single(recordIndex: 2)
        ])
        #expect(collapser.expandedGroups == [0])

        let isCollapsed = collapser.toggleGroup(atRow: 0)
        let isSingleToggled = collapser.toggleGroup(atRow: 1)
        let isMissingToggled = collapser.toggleGroup(atRow: 9)

        #expect(isCollapsed)
        #expect(collapser.rowCount == 2)
        #expect(collapser.expandedGroups.isEmpty)
        #expect(isSingleToggled == false)
        #expect(isMissingToggled == false)
    }

    @Test func expandGroupContainingARecord() {
        var collapser = makeCollapser(recordIndices: [2, 3, 4, 5])

        let isSingleExpanded = collapser.expandGroup(containing: 2)
        let isGroupExpanded = collapser.expandGroup(containing: 5)
        let isExpandedAgain = collapser.expandGroup(containing: 5)

        #expect(isSingleExpanded == false)
        #expect(isGroupExpanded)
        #expect(isExpandedAgain == false)
        #expect(collapser.rowIndex(ofRecord: 5) == 3)
    }

    @Test func rowIndexOfARecordInCollapsedAndExpandedGroups() {
        var collapser = makeCollapser(recordIndices: [0, 1, 3, 4, 5])

        #expect(collapser.rowIndex(ofRecord: 0) == 0)
        #expect(collapser.rowIndex(ofRecord: 1) == 0)
        #expect(collapser.rowIndex(ofRecord: 4) == 1)
        #expect(collapser.rowIndex(ofRecord: 2) == nil)
        #expect(collapser.rowIndex(ofRecord: 7) == nil)

        _ = collapser.toggleGroup(atRow: 1)

        #expect(collapser.rowIndex(ofRecord: 3) == 1)
        #expect(collapser.rowIndex(ofRecord: 4) == 2)
        #expect(collapser.rowIndex(ofRecord: 5) == 3)
    }

    @Test func rebuildKeepsTheExpandedGroups() {
        var collapser = makeCollapser(recordIndices: [3, 4, 5])
        _ = collapser.toggleGroup(atRow: 0)

        collapser.rebuild(recordIndices: [2, 3, 4], key: key)

        #expect(collapser.expandedGroups == [3])
        #expect(collapser.rows == [
            .single(recordIndex: 2),
            .group(firstRecordIndex: 3, recordIndices: [3, 4], isExpanded: true),
            .member(recordIndex: 4, firstRecordIndex: 3)
        ])
    }

    private func key(_ recordIndex: Int) -> String {
        keys[recordIndex]
    }

    private func makeCollapser(recordIndices: [Int]) -> RowCollapser {
        var collapser = RowCollapser()
        collapser.rebuild(recordIndices: recordIndices, key: key)
        return collapser
    }
}
