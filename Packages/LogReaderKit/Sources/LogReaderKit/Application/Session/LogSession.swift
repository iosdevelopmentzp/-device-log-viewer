import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class LogSession {

    public let url: URL

    public private(set) var status: LogSessionStatus = .loading
    public private(set) var content: LogContent
    public private(set) var facetCounts: FacetCounts
    public private(set) var visible: [Int] = []
    public private(set) var findMatches: [Int] = []
    public private(set) var findMatchSet: Set<Int> = []
    public private(set) var bookmarks: Set<Int> = []
    public private(set) var newEntriesWhileDetached = 0
    public private(set) var isFiltering = false
    public private(set) var filterState: LogFilterState

    public var selectedRecords: [Int] = []
    public var isFollowing = true {
        didSet {
            guard isFollowing else { return }
            newEntriesWhileDetached = 0
        }
    }

    public var profile: LogProfile { content.profile }

    public var hasTimeRange: Bool { filterState.timeRange != nil }

    public var hasClearedEntries: Bool { filterState.hasClearedEntries }

    public var clearedCounts: (before: Int, after: Int, selected: Int) {
        let after = filterState.clearedAfterRange?.count ?? 0
        let before = filterState.markIndex.map { min($0, content.records.count) } ?? 0
        return (before: before, after: after, selected: filterState.clearedOffsets.count)
    }

    public var primarySelection: LogRecord? {
        selectedRecords.last.flatMap(record(at:))
    }

    public var findPosition: Int? {
        selectedRecords.last.flatMap { SortedIndices.position(of: $0, in: findMatches) }
    }

    @ObservationIgnored public weak var rowsObserver: (any LogRowsObserver)?
    @ObservationIgnored public weak var appendObserver: (any LogAppendObserver)?

    @ObservationIgnored private let source: any LogSource
    @ObservationIgnored private let bookmarkRepository: any BookmarkRepository
    @ObservationIgnored private let filterRunner: LogFilterRunner
    @ObservationIgnored private var eventsTask: Task<Void, Never>?

    private static let synchronousFilterLimit = 5_000

    public init(
        url: URL,
        profile: LogProfile,
        source: any LogSource,
        bookmarkRepository: any BookmarkRepository,
        filterRunner: LogFilterRunner,
        searchScope: SearchScope,
        isRegex: Bool
    ) {
        self.url = url
        self.content = LogContent(profile: profile)
        self.facetCounts = FacetCounts(profile: profile)
        self.source = source
        self.bookmarkRepository = bookmarkRepository
        self.filterRunner = filterRunner
        self.filterState = LogFilterState(searchScope: searchScope, isRegex: isRegex)
    }

    public func start() {
        bookmarks = bookmarkRepository.bookmarks(for: url)
        let events = source.events()
        eventsTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                handle(event)
            }
        }
    }

    public func stop() {
        eventsTask?.cancel()
        filterRunner.cancel()
        source.stop()
    }

    public func record(atRow row: Int) -> LogRecord? {
        recordIndex(atRow: row).flatMap(record(at:))
    }

    public func recordIndex(atRow row: Int) -> Int? {
        guard visible.indices.contains(row) else { return nil }
        return visible[row]
    }

    public func record(at index: Int) -> LogRecord? {
        guard content.records.indices.contains(index) else { return nil }
        return content.records[index]
    }

    public func previousRecord(before index: Int) -> LogRecord? {
        record(at: index - 1)
    }

    public func text(of record: LogRecord) -> String {
        content.text(of: record)
    }

    public func isBookmarked(_ record: LogRecord) -> Bool {
        bookmarks.contains(record.offset)
    }

    public func jumpToEnd() {
        isFollowing = true
        notify(.scrollToEnd)
    }

    public func select(recordIndex: Int) {
        guard let row = SortedIndices.nearestPosition(of: recordIndex, in: visible) else { return }
        isFollowing = false
        notify(.select(row: row))
    }

    public func goToEntry(number: Int) {
        guard content.records.isEmpty == false else { return }
        select(recordIndex: min(max(number - 1, 0), content.records.count - 1))
    }

    public func findNext() {
        guard let next = SortedIndices.next(after: selectedRecords.last ?? -1, in: findMatches) else { return }
        select(recordIndex: next)
    }

    public func findPrevious() {
        guard let previous = SortedIndices.previous(before: selectedRecords.last ?? Int.max, in: findMatches) else { return }
        select(recordIndex: previous)
    }

    public func nextBookmark() {
        guard let next = SortedIndices.next(after: selectedRecords.last ?? -1, in: bookmarkedVisibleRecords()) else { return }
        select(recordIndex: next)
    }

    public func previousBookmark() {
        let bookmarked = bookmarkedVisibleRecords()
        guard let previous = SortedIndices.previous(before: selectedRecords.last ?? Int.max, in: bookmarked) else { return }
        select(recordIndex: previous)
    }

    public func toggleBookmarks(recordIndices: [Int]) {
        let offsets = recordIndices.compactMap(record(at:)).map(\.offset)
        guard offsets.isEmpty == false else { return }
        let shouldAdd = offsets.contains { bookmarks.contains($0) == false }
        if shouldAdd {
            bookmarks.formUnion(offsets)
        } else {
            bookmarks.subtract(offsets)
        }
        bookmarkRepository.save(bookmarks, for: url)
        if filterState.bookmarksOnly {
            scheduleRefilter(debounced: false)
        } else {
            notify(.refreshRows)
        }
    }

    public func toggleBookmarkForSelection() {
        toggleBookmarks(recordIndices: selectedRecords)
    }

    public func clearBookmarks() {
        guard bookmarks.isEmpty == false else { return }
        bookmarks = []
        bookmarkRepository.save(bookmarks, for: url)
        if filterState.bookmarksOnly {
            scheduleRefilter(debounced: false)
        } else {
            notify(.refreshRows)
        }
    }

    public func showInFullLog(recordIndex: Int) {
        selectedRecords = [recordIndex]
        isFollowing = false
        clearFilters()
    }

    public func clearFilters() {
        updateFilterState(debounced: false) { $0.clear() }
    }

    public func setSearchText(_ text: String) {
        updateFilterState(debounced: true) { $0.searchText = text }
    }

    public func setSearchMode(_ mode: SearchMode) {
        updateFilterState(debounced: false) { $0.searchMode = mode }
    }

    public func setSearchScope(_ scope: SearchScope) {
        guard scope.isEmpty == false, scope != filterState.searchScope else { return }
        filterState.searchScope = scope
        guard filterState.searchText.isEmpty == false || filterState.activeExtraTerms.isEmpty == false else { return }
        scheduleRefilter(debounced: false)
    }

    public func setRegex(_ isRegex: Bool) {
        updateFilterState(debounced: false) { $0.isRegex = isRegex }
    }

    public func setExtraTerms(_ terms: [SearchTerm]) {
        updateExtraTerms(debounced: true) { $0 = Array(terms.prefix(LogFilterState.maxExtraTerms)) }
    }

    public func addExtraTerm() {
        guard filterState.canAddExtraTerm else { return }
        updateExtraTerms(debounced: false) { $0.append(SearchTerm(text: "", isNegated: false)) }
    }

    public func removeExtraTerm(at index: Int) {
        guard filterState.extraTerms.indices.contains(index) else { return }
        updateExtraTerms(debounced: false) { $0.remove(at: index) }
    }

    public func updateExtraTerm(at index: Int, text: String) {
        guard filterState.extraTerms.indices.contains(index) else { return }
        updateExtraTerms(debounced: true) { terms in
            terms[index] = SearchTerm(text: text, isNegated: terms[index].isNegated)
        }
    }

    public func setExtraTermNegated(at index: Int, _ isNegated: Bool) {
        guard filterState.extraTerms.indices.contains(index) else { return }
        updateExtraTerms(debounced: false) { terms in
            terms[index] = SearchTerm(text: terms[index].text, isNegated: isNegated)
        }
    }

    public func toggleSearchScope(_ id: String) {
        var scope = filterState.searchScope
        scope.toggle(id)
        setSearchScope(scope)
    }

    public func toggleFacetValue(_ value: String, in column: FacetColumn) {
        updateFilterState(debounced: false) { $0.facets.toggle(value, in: column) }
    }

    public func showOnly(_ values: Set<String>, in column: FacetColumn) {
        updateFilterState(debounced: false) { $0.facets.showOnly(values, in: column) }
    }

    public func exclude(_ values: Set<String>, in column: FacetColumn) {
        updateFilterState(debounced: false) { $0.facets.addExcluded(values, in: column) }
    }

    public func hideOnly(_ values: Set<String>, in column: FacetColumn) {
        updateFilterState(debounced: false) { $0.facets.exclude(values, in: column) }
    }

    public func setFacetMode(_ mode: FacetMode, in column: FacetColumn) {
        updateFilterState(debounced: false) { $0.facets.setMode(mode, in: column) }
    }

    public func showAll(in column: FacetColumn) {
        updateFilterState(debounced: false) { $0.facets.showAll(in: column) }
    }

    public func setLevels(_ levels: FacetFilter<String>) {
        updateFilterState(debounced: false) { $0.facets[.level] = levels }
    }

    public func setBookmarksOnly(_ bookmarksOnly: Bool) {
        updateFilterState(debounced: false) { $0.bookmarksOnly = bookmarksOnly }
    }

    public func applyFacets(_ facets: FacetSelection, bookmarksOnly: Bool) {
        updateFilterState(debounced: false) { state in
            state.facets = facets
            state.bookmarksOnly = bookmarksOnly
        }
    }

    public func apply(_ preset: FilterPreset) {
        updateFilterState(debounced: false) { $0.apply(preset) }
    }

    public func setTimeRange(_ range: ClosedRange<TimeInterval>?) {
        updateFilterState(debounced: false) { $0.timeRange = range }
    }

    public func clearTimeRange() {
        setTimeRange(nil)
    }

    public func setTimeRangeFromSelection() {
        guard let range = timeRangeOfSelection() else { return }
        setTimeRange(range)
    }

    public func timeRangeOfSelection() -> ClosedRange<TimeInterval>? {
        let timestamps = selectedRecords.compactMap { record(at: $0)?.timestamp }
        guard let lower = timestamps.min(), let upper = timestamps.max() else { return nil }
        guard selectedRecords.count > 1 else { return lower...Double.greatestFiniteMagnitude }
        return lower...upper
    }

    public func clearAllEntries() {
        let index = content.records.count
        updateFilterState(debounced: false) { state in
            state.restoreAllEntries()
            state.markIndex = index
        }
    }

    public func clearEntries(before recordIndex: Int) {
        updateFilterState(debounced: false) { $0.markIndex = recordIndex }
    }

    public func clearEntries(after recordIndex: Int) {
        let range = (recordIndex + 1)..<max(recordIndex + 1, content.records.count)
        updateFilterState(debounced: false) { $0.clearedAfterRange = range.isEmpty ? nil : range }
    }

    public func clearEntriesBeforeSelection() {
        guard selectedRecords.count == 1, let recordIndex = selectedRecords.first else { return }
        clearEntries(before: recordIndex)
    }

    public func clearEntriesAfterSelection() {
        guard selectedRecords.count == 1, let recordIndex = selectedRecords.first else { return }
        clearEntries(after: recordIndex)
    }

    public func clearEntries(recordIndices: [Int]) {
        let offsets = recordIndices.compactMap(record(at:)).map(\.offset)
        guard offsets.isEmpty == false else { return }
        selectedRecords = []
        updateFilterState(debounced: false) { $0.clearedOffsets.formUnion(offsets) }
    }

    public func clearSelectedEntries() {
        clearEntries(recordIndices: selectedRecords)
    }

    public func restoreBefore() {
        updateFilterState(debounced: false) { $0.markIndex = nil }
    }

    public func restoreAfter() {
        updateFilterState(debounced: false) { $0.clearedAfterRange = nil }
    }

    public func restoreSelected() {
        updateFilterState(debounced: false) { $0.clearedOffsets = [] }
    }

    public func restoreAllEntries() {
        updateFilterState(debounced: false) { $0.restoreAllEntries() }
    }
}

// MARK: - Private

private extension LogSession {

    func handle(_ event: LogSourceEvent) {
        switch event {
        case .batch(let batch):
            let range = content.append(batch)
            facetCounts.add(content.records[range])
            appendObserver?.session(self, didAppend: range)
            status = .live
            appendVisible(range)
        case .reset:
            reset()
        case .missing:
            status = .missing
        }
    }

    func reset() {
        filterRunner.cancel()
        isFiltering = false
        content = LogContent(profile: profile)
        facetCounts.removeAll()
        visible = []
        findMatches = []
        findMatchSet = []
        selectedRecords = []
        newEntriesWhileDetached = 0
        filterState.restoreAllEntries()
        bookmarks = []
        bookmarkRepository.save(bookmarks, for: url)
        notify(.reload)
    }

    func updateFilterState(debounced: Bool, _ change: (inout LogFilterState) -> Void) {
        var state = filterState
        change(&state)
        guard state != filterState else { return }
        filterState = state
        scheduleRefilter(debounced: debounced)
    }

    func updateExtraTerms(debounced: Bool, _ change: (inout [SearchTerm]) -> Void) {
        var state = filterState
        change(&state.extraTerms)
        guard state != filterState else { return }
        let needsRefilter = state.activeExtraTerms != filterState.activeExtraTerms
        filterState = state
        guard needsRefilter else { return }
        scheduleRefilter(debounced: debounced)
    }

    func makeRequest(range: Range<Int>) -> FilterRequest {
        FilterRequest(
            content: content,
            range: range,
            filter: filterState.makeFilter(bookmarks: bookmarks),
            findQuery: filterState.findQuery,
            findTerms: filterState.findTerms
        )
    }

    func appendVisible(_ range: Range<Int>) {
        guard isFiltering == false else { return }
        let request = makeRequest(range: range)
        guard request.filter.isPassThrough || range.count <= Self.synchronousFilterLimit else {
            scheduleRefilter(debounced: false)
            return
        }
        guard let result = try? FilterResult.compute(request), result.visible.isEmpty == false else { return }
        findMatches.append(contentsOf: result.findMatches)
        findMatchSet.formUnion(result.findMatches)
        let lower = visible.count
        visible.append(contentsOf: result.visible)
        if isFollowing == false {
            newEntriesWhileDetached += result.visible.count
        }
        notify(.inserted(lower..<visible.count))
    }

    func scheduleRefilter(debounced: Bool) {
        isFiltering = true
        let upperBound = content.records.count
        let request = makeRequest(range: 0..<upperBound)
        Task { [weak self] in
            guard let self else { return }
            guard let result = await filterRunner.run(request, debounced: debounced) else { return }
            apply(result, upperBound: upperBound)
        }
    }

    func apply(_ result: FilterResult, upperBound: Int) {
        visible = result.visible
        findMatches = result.findMatches
        findMatchSet = Set(result.findMatches)
        isFiltering = false
        notify(.reload)
        if upperBound < content.records.count {
            appendVisible(upperBound..<content.records.count)
        }
        if isFollowing {
            notify(.scrollToEnd)
        } else if let selected = selectedRecords.last {
            select(recordIndex: selected)
        }
    }

    func bookmarkedVisibleRecords() -> [Int] {
        guard bookmarks.isEmpty == false else { return [] }
        return visible.filter { bookmarks.contains(content.records[$0].offset) }
    }

    func notify(_ event: LogRowsEvent) {
        rowsObserver?.handle(event)
    }
}
