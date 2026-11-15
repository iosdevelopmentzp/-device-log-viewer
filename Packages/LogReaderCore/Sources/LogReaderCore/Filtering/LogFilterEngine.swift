import Foundation

public enum LogFilterEngine {

    fileprivate struct CompiledFacets {
        let levels: FacetFilter<LogLevel>
        let attributes: [(index: Int, rule: AttributeRule, filter: FacetFilter<String>)]
    }

    fileprivate struct CompiledScope {
        let includesMessage: Bool
        let includesLevel: Bool
        let attributes: [(index: Int, prefix: String)]
    }

    fileprivate typealias Queries = (main: TextQuery?, positive: [TextQuery], negative: [TextQuery])

    private static let cancellationCheckInterval = 2_048

    public static func indices(in content: LogContent, range: Range<Int>, filter: LogFilter) throws -> [Int] {
        guard filter.isPassThrough == false else { return Array(range) }
        let queries = makeQueries(filter)
        let facets = compile(filter.facets, profile: content.profile)
        let scope = compile(filter.scope, profile: content.profile)
        var result: [Int] = []
        let lowerBound = min(max(range.lowerBound, filter.startIndex ?? 0), range.upperBound)
        for index in lowerBound..<range.upperBound {
            if (index - lowerBound) % cancellationCheckInterval == 0 {
                try Task.checkCancellation()
            }
            if let hiddenRange = filter.hiddenRange, hiddenRange.contains(index) {
                continue
            }
            if matches(content.records[index], in: content, filter: filter, facets: facets, queries: queries, scope: scope) {
                result.append(index)
            }
        }
        return result
    }

    public static func textMatches(
        in content: LogContent,
        candidates: [Int],
        query: TextQuery?,
        terms: [SearchTerm],
        isRegex: Bool,
        scope: SearchScope
    ) throws -> [Int] {
        let termQueries = makeTermQueries(terms, isRegex: isRegex)
        guard query != nil || termQueries.positive.isEmpty == false || termQueries.negative.isEmpty == false else {
            return []
        }
        let queries = (main: query, positive: termQueries.positive, negative: termQueries.negative)
        let compiledScope = compile(scope, profile: content.profile)
        var result: [Int] = []
        for (position, index) in candidates.enumerated() {
            if position % cancellationCheckInterval == 0 {
                try Task.checkCancellation()
            }
            if textMatches(content.records[index], in: content, queries: queries, scope: compiledScope) {
                result.append(index)
            }
        }
        return result
    }

    public static func matches(_ record: LogRecord, in content: LogContent, filter: LogFilter, query: TextQuery?) -> Bool {
        let termQueries = makeTermQueries(filter.extraTerms, isRegex: filter.isRegex)
        let queries = (main: query, positive: termQueries.positive, negative: termQueries.negative)
        return matches(
            record,
            in: content,
            filter: filter,
            facets: compile(filter.facets, profile: content.profile),
            queries: queries,
            scope: compile(filter.scope, profile: content.profile)
        )
    }

    public static func matches(_ record: LogRecord, in content: LogContent, query: TextQuery, scope: SearchScope) -> Bool {
        matches(record, in: content, query: query, scope: compile(scope, profile: content.profile))
    }
}

// MARK: - Private

private extension LogFilterEngine {

    static func compile(_ facets: FacetSelection, profile: LogProfile) -> CompiledFacets {
        let levelFilter: FacetFilter<LogLevel>
        switch facets.levels {
        case .all: levelFilter = .all
        case .only(let ids): levelFilter = .only(Set(ids.compactMap(profile.level(id:))))
        case .except(let ids): levelFilter = .except(Set(ids.compactMap(profile.level(id:))))
        }
        let attributes = facets.activeColumns.compactMap { column -> (index: Int, rule: AttributeRule, filter: FacetFilter<String>)? in
            guard let id = column.attributeID, let index = profile.attributeIndex(id: id) else { return nil }
            return (index, profile.attributes[index], facets[column])
        }
        return CompiledFacets(levels: levelFilter, attributes: attributes)
    }

    static func compile(_ scope: SearchScope, profile: LogProfile) -> CompiledScope {
        let attributes = profile.attributes.enumerated()
            .filter { scope.contains($0.element.id) }
            .map { (index: $0.offset, prefix: $0.element.prefix) }
        return CompiledScope(includesMessage: scope.includesMessage, includesLevel: scope.includesLevel, attributes: attributes)
    }

    static func makeQueries(_ filter: LogFilter) -> Queries {
        let termQueries = makeTermQueries(filter.extraTerms, isRegex: filter.isRegex)
        let main = makeQuery(text: filter.text, isRegex: filter.isRegex)
        return (main: main, positive: termQueries.positive, negative: termQueries.negative)
    }

    static func makeTermQueries(_ terms: [SearchTerm], isRegex: Bool) -> (positive: [TextQuery], negative: [TextQuery]) {
        var positive: [TextQuery] = []
        var negative: [TextQuery] = []
        for term in terms {
            guard let query = makeQuery(text: term.text, isRegex: isRegex) else { continue }
            if term.isNegated {
                negative.append(query)
            } else {
                positive.append(query)
            }
        }
        return (positive: positive, negative: negative)
    }

    static func makeQuery(text: String, isRegex: Bool) -> TextQuery? {
        guard isRegex, text.isEmpty == false else { return TextQuery(text) }
        return try? TextQuery.regex(text)
    }

    static func matches(
        _ record: LogRecord,
        in content: LogContent,
        filter: LogFilter,
        facets: CompiledFacets,
        queries: Queries,
        scope: CompiledScope
    ) -> Bool {
        guard facets.levels.allows(record.level) else { return false }
        for facet in facets.attributes {
            let value = content.profile.value(of: record, attribute: facet.index)
            guard facet.filter.allowsAny(of: facet.rule.facetValues(of: value)) else { return false }
        }
        if let onlyOffsets = filter.onlyOffsets {
            guard onlyOffsets.contains(record.offset) else { return false }
        }
        if let hiddenOffsets = filter.hiddenOffsets {
            guard hiddenOffsets.contains(record.offset) == false else { return false }
        }
        if let timeRange = filter.timeRange {
            guard let timestamp = record.timestamp, timeRange.contains(timestamp) else { return false }
        }
        return textMatches(record, in: content, queries: queries, scope: scope)
    }

    static func textMatches(_ record: LogRecord, in content: LogContent, queries: Queries, scope: CompiledScope) -> Bool {
        if let main = queries.main {
            guard matches(record, in: content, query: main, scope: scope) else { return false }
        }
        for query in queries.positive {
            guard matches(record, in: content, query: query, scope: scope) else { return false }
        }
        for query in queries.negative {
            guard matches(record, in: content, query: query, scope: scope) == false else { return false }
        }
        return true
    }

    static func matches(_ record: LogRecord, in content: LogContent, query: TextQuery, scope: CompiledScope) -> Bool {
        if scope.includesMessage, messageMatches(record, in: content, query: query) { return true }
        for attribute in scope.attributes {
            let values = content.profile.value(of: record, attribute: attribute.index).values
            if values.contains(where: { query.matches(attribute.prefix + $0) }) { return true }
        }
        if scope.includesLevel, let level = record.level, let rule = content.profile.rule(of: level),
           rule.codes.contains(where: query.matches) || query.matches(rule.title) {
            return true
        }
        return false
    }

    static func messageMatches(_ record: LogRecord, in content: LogContent, query: TextQuery) -> Bool {
        content.withBytes(of: record) { bytes in
            let metadata = record.metadataRange
            guard metadata.isEmpty == false else { return query.matches(bytes) }
            let before = UnsafeRawBufferPointer(rebasing: bytes[0..<metadata.lowerBound])
            let after = UnsafeRawBufferPointer(rebasing: bytes[metadata.upperBound..<bytes.count])
            return query.matches(before) || query.matches(after)
        }
    }
}
