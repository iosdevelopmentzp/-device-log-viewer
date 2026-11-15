import Foundation
import LogReaderCore

public struct LogFilterState: Sendable, Equatable {

    public var searchText: String
    public var searchMode: SearchMode
    public var searchScope: SearchScope
    public var isRegex: Bool
    public var facets: FacetSelection
    public var bookmarksOnly: Bool
    public var timeRange: ClosedRange<TimeInterval>?
    public var markIndex: Int?
    public var clearedAfterRange: Range<Int>?
    public var clearedOffsets: Set<Int>
    public var extraTerms: [SearchTerm]

    public var hasActiveFilters: Bool {
        makeFilter(bookmarks: []).isPassThrough == false
            || (searchMode == .find && searchText.isEmpty == false)
            || activeExtraTerms.isEmpty == false
    }

    public var hasClearedEntries: Bool {
        markIndex != nil || clearedAfterRange != nil || clearedOffsets.isEmpty == false
    }

    public var hasPresetContent: Bool {
        searchText.isEmpty == false || facets.isAll == false || bookmarksOnly || activeExtraTerms.isEmpty == false
    }

    public var activeExtraTerms: [SearchTerm] {
        extraTerms.filter { $0.text.isEmpty == false }
    }

    public var canAddExtraTerm: Bool {
        extraTerms.count < Self.maxExtraTerms
    }

    public var findQuery: TextQuery? {
        guard searchMode == .find else { return nil }
        return highlightQuery
    }

    public var findTerms: [SearchTerm] {
        searchMode == .find ? activeExtraTerms : []
    }

    public var highlightQuery: TextQuery? {
        makeQuery(searchText)
    }

    public var highlightQueries: [TextQuery] {
        let termQueries = activeExtraTerms
            .filter { $0.isNegated == false }
            .compactMap { makeQuery($0.text) }
        return [highlightQuery].compactMap { $0 } + termQueries
    }

    public static let maxExtraTerms = 3

    public init(searchScope: SearchScope, isRegex: Bool) {
        self.searchText = ""
        self.searchMode = .filter
        self.searchScope = searchScope
        self.isRegex = isRegex
        self.facets = .all
        self.bookmarksOnly = false
        self.timeRange = nil
        self.markIndex = nil
        self.clearedAfterRange = nil
        self.clearedOffsets = []
        self.extraTerms = []
    }

    public init(preset: FilterPreset) {
        self.searchText = preset.searchText
        self.searchMode = preset.searchMode
        self.searchScope = preset.searchScope
        self.isRegex = preset.isRegex
        self.facets = preset.facets
        self.bookmarksOnly = preset.bookmarksOnly
        self.timeRange = nil
        self.markIndex = nil
        self.clearedAfterRange = nil
        self.clearedOffsets = []
        self.extraTerms = preset.extraTerms
    }

    public func makeFilter(bookmarks: Set<Int>) -> LogFilter {
        LogFilter(
            text: searchMode == .filter ? searchText : "",
            isRegex: isRegex,
            scope: searchScope,
            facets: facets,
            onlyOffsets: bookmarksOnly ? bookmarks : nil,
            timeRange: timeRange,
            startIndex: markIndex,
            hiddenRange: clearedAfterRange,
            hiddenOffsets: clearedOffsets.isEmpty ? nil : clearedOffsets,
            extraTerms: searchMode == .filter ? activeExtraTerms : []
        )
    }

    public func makePreset(name: String) -> FilterPreset {
        FilterPreset(
            id: UUID(),
            name: name,
            searchText: searchText,
            searchMode: searchMode,
            searchScope: searchScope,
            isRegex: isRegex,
            facets: facets,
            bookmarksOnly: bookmarksOnly,
            extraTerms: activeExtraTerms
        )
    }

    public mutating func apply(_ preset: FilterPreset) {
        var state = LogFilterState(preset: preset)
        state.markIndex = markIndex
        state.clearedAfterRange = clearedAfterRange
        state.clearedOffsets = clearedOffsets
        self = state
    }

    public mutating func clear() {
        searchText = ""
        facets = .all
        bookmarksOnly = false
        timeRange = nil
        extraTerms = []
        restoreAllEntries()
    }

    public mutating func restoreAllEntries() {
        markIndex = nil
        clearedAfterRange = nil
        clearedOffsets = []
    }
}

// MARK: - Private

private extension LogFilterState {

    func makeQuery(_ text: String) -> TextQuery? {
        guard isRegex, text.isEmpty == false else { return TextQuery(text) }
        return try? TextQuery.regex(text)
    }
}
