import Foundation
import LogReaderCore

struct RowCollapser {

    private(set) var rows: [TableRow] = []
    private(set) var expandedGroups: Set<Int> = []
    private var lastKey: String?

    var rowCount: Int { rows.count }

    init() {}

    mutating func rebuild(recordIndices: [Int], key: (Int) -> String) {
        rows = []
        lastKey = nil
        var run: [Int] = []
        for index in recordIndices {
            let indexKey = key(index)
            if indexKey != lastKey, run.isEmpty == false {
                appendRun(run)
                run = []
            }
            run.append(index)
            lastKey = indexKey
        }
        if run.isEmpty == false {
            appendRun(run)
        }
    }

    mutating func append(recordIndices: [Int], key: (Int) -> String) -> AppendResult {
        let initialCount = rows.count
        var changedRow: Int?
        for index in recordIndices {
            let indexKey = key(index)
            defer { lastKey = indexKey }
            guard indexKey == lastKey, let runRow = lastRunRow else {
                rows.append(.single(recordIndex: index))
                continue
            }
            extendRun(atRow: runRow, with: index)
            if runRow < initialCount {
                changedRow = runRow
            }
        }
        return AppendResult(insertedRows: initialCount..<rows.count, changedRow: changedRow)
    }

    func row(at row: Int) -> TableRow? {
        guard rows.indices.contains(row) else { return nil }
        return rows[row]
    }

    func recordIndex(atRow row: Int) -> Int? {
        self.row(at: row).map(Self.anchor(of:))
    }

    func rowIndex(ofRecord recordIndex: Int) -> Int? {
        guard let candidate = lastRow(withAnchorAtMost: recordIndex) else { return nil }
        switch rows[candidate] {
        case .single(let index), .member(let index, _):
            return index == recordIndex ? candidate : nil
        case .group(_, let indices, let isExpanded):
            guard isExpanded == false || indices.first == recordIndex else { return nil }
            return SortedIndices.position(of: recordIndex, in: indices) == nil ? nil : candidate
        }
    }

    mutating func toggleGroup(atRow row: Int) -> Bool {
        guard case .group(let first, let indices, let isExpanded) = self.row(at: row) else { return false }
        if isExpanded {
            rows.removeSubrange((row + 1)..<(row + indices.count))
            expandedGroups.remove(first)
        } else {
            rows.insert(contentsOf: Self.members(of: indices), at: row + 1)
            expandedGroups.insert(first)
        }
        rows[row] = .group(firstRecordIndex: first, recordIndices: indices, isExpanded: isExpanded == false)
        return true
    }

    mutating func expandGroup(containing recordIndex: Int) -> Bool {
        guard let row = rowIndex(ofRecord: recordIndex),
              case .group(_, _, false) = rows[row] else { return false }
        return toggleGroup(atRow: row)
    }
}

// MARK: - Private

private extension RowCollapser {

    var lastRunRow: Int? {
        guard let last = rows.last else { return nil }
        guard case .member(_, let first) = last else { return rows.count - 1 }
        return rowIndex(ofRecord: first)
    }

    static func anchor(of row: TableRow) -> Int {
        switch row {
        case .single(let index), .member(let index, _): index
        case .group(let first, _, _): first
        }
    }

    static func members(of indices: [Int]) -> [TableRow] {
        guard let first = indices.first else { return [] }
        return indices.dropFirst().map { .member(recordIndex: $0, firstRecordIndex: first) }
    }

    func lastRow(withAnchorAtMost recordIndex: Int) -> Int? {
        var low = 0
        var high = rows.count
        while low < high {
            let middle = (low + high) / 2
            if Self.anchor(of: rows[middle]) <= recordIndex {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low == 0 ? nil : low - 1
    }

    mutating func appendRun(_ run: [Int]) {
        guard let first = run.first, run.count > 1 else {
            rows.append(contentsOf: run.map { .single(recordIndex: $0) })
            return
        }
        let isExpanded = expandedGroups.contains(first)
        rows.append(.group(firstRecordIndex: first, recordIndices: run, isExpanded: isExpanded))
        if isExpanded {
            rows.append(contentsOf: Self.members(of: run))
        }
    }

    mutating func extendRun(atRow row: Int, with index: Int) {
        switch rows[row] {
        case .single(let first):
            let isExpanded = expandedGroups.contains(first)
            rows[row] = .group(firstRecordIndex: first, recordIndices: [first, index], isExpanded: isExpanded)
            if isExpanded {
                rows.append(.member(recordIndex: index, firstRecordIndex: first))
            }
        case .group(let first, let indices, let isExpanded):
            rows[row] = .group(firstRecordIndex: first, recordIndices: indices + [index], isExpanded: isExpanded)
            if isExpanded {
                rows.append(.member(recordIndex: index, firstRecordIndex: first))
            }
        case .member:
            break
        }
    }
}
