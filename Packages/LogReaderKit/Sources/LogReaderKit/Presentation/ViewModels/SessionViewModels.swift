import Foundation

@MainActor
public struct SessionViewModels {
    public let session: LogSession
    public let table: LogTablePresenter
    public let search: SearchViewModel
    public let inspector: EntryInspectorViewModel
    public let filterMenu: FilterMenuViewModel
    public let chips: FilterChipsViewModel
    public let cleared: ClearedEntriesViewModel
    public let terms: SearchTermsViewModel

    public init(
        session: LogSession,
        table: LogTablePresenter,
        search: SearchViewModel,
        inspector: EntryInspectorViewModel,
        filterMenu: FilterMenuViewModel,
        chips: FilterChipsViewModel,
        cleared: ClearedEntriesViewModel,
        terms: SearchTermsViewModel
    ) {
        self.session = session
        self.table = table
        self.search = search
        self.inspector = inspector
        self.filterMenu = filterMenu
        self.chips = chips
        self.cleared = cleared
        self.terms = terms
    }
}
