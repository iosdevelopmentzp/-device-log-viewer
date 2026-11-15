import AppKit
import LogReaderKit

final class LogTableRowHeightCache {

    private var heights: [Int: (columns: Int, height: CGFloat)] = [:]
    private var recordCount = 0
    private var recalculation: DispatchWorkItem?

    private static let recalculationDelay: TimeInterval = 0.15

    func height(row: Int, columns: Int, presenter: LogTablePresenter, lineHeight: CGFloat, verticalInset: CGFloat, maxLines: Int) -> CGFloat {
        guard let index = presenter.recordIndex(atRow: row) else { return lineHeight + verticalInset * 2 }
        if let cached = heights[index], cached.columns == columns {
            return cached.height
        }
        let lines = presenter.lineCount(row: row, columns: columns, maxLines: maxLines)
        let height = CGFloat(lines) * lineHeight + verticalInset * 2
        heights[index] = (columns, height)
        return height
    }

    func removeAll() {
        heights.removeAll()
    }

    func update(recordCount newCount: Int) {
        if newCount < recordCount {
            heights.removeAll()
        }
        recordCount = newCount
    }

    func scheduleRecalculation(for tableView: NSTableView) {
        recalculation?.cancel()
        let work = DispatchWorkItem { [weak self, weak tableView] in
            guard let self else { return }
            guard let tableView else { return }
            heights.removeAll()
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
        }
        recalculation = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.recalculationDelay, execute: work)
    }
}
