import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class SearchTermsViewModel {

    @ObservationIgnored private let session: LogSession

    public let containsTitle = "Also contains"
    public let excludesTitle = "Does not contain"
    public let prompt = "Text"
    public let joinTitle = "and"

    public var items: [SearchTermItem] {
        session.filterState.extraTerms.enumerated().map { index, term in
            SearchTermItem(id: index, text: term.text, isNegated: term.isNegated)
        }
    }

    public var isEmpty: Bool { session.filterState.extraTerms.isEmpty }

    public var canAdd: Bool { session.filterState.canAddExtraTerm }

    public init(session: LogSession) {
        self.session = session
    }

    public func add() {
        session.addExtraTerm()
    }

    public func remove(id: Int) {
        session.removeExtraTerm(at: id)
    }

    public func setText(id: Int, _ text: String) {
        session.updateExtraTerm(at: id, text: text)
    }

    public func setNegated(id: Int, _ isNegated: Bool) {
        session.setExtraTermNegated(at: id, isNegated)
    }
}
