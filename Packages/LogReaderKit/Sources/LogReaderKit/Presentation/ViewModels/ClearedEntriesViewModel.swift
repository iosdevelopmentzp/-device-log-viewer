import Foundation
import Observation

@MainActor
@Observable
public final class ClearedEntriesViewModel {

    @ObservationIgnored private let session: LogSession

    public var isActive: Bool { session.hasClearedEntries }

    public var summaryText: String {
        let shown = GroupedNumberText.text(session.visible.count)
        let total = GroupedNumberText.text(session.content.records.count)
        return "Showing \(shown) of \(total) entries"
    }

    public var parts: [ClearedPartItem] {
        let state = session.filterState
        let counts = session.clearedCounts
        var parts = [ClearedPartItem]()
        if let markIndex = state.markIndex {
            let title = "\(GroupedNumberText.text(counts.before)) cleared before #\(GroupedNumberText.text(markIndex + 1))"
            parts.append(ClearedPartItem(id: "before", title: title, kind: .before))
        }
        if let clearedAfterRange = state.clearedAfterRange {
            let title = "\(GroupedNumberText.text(counts.after)) cleared after #\(GroupedNumberText.text(clearedAfterRange.lowerBound))"
            parts.append(ClearedPartItem(id: "after", title: title, kind: .after))
        }
        if counts.selected > 0 {
            let noun = counts.selected == 1 ? "entry" : "entries"
            let title = "\(GroupedNumberText.text(counts.selected)) selected \(noun) cleared"
            parts.append(ClearedPartItem(id: "selected", title: title, kind: .selected))
        }
        return parts
    }

    public init(session: LogSession) {
        self.session = session
    }

    public func restore(part: ClearedPartItem) {
        switch part.kind {
        case .before: session.restoreBefore()
        case .after: session.restoreAfter()
        case .selected: session.restoreSelected()
        }
    }

    public func restoreAll() {
        session.restoreAllEntries()
    }
}
