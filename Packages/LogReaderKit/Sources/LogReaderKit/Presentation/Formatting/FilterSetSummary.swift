import Foundation
import LogReaderCore

public enum FilterSetSummary {

    private static let separator = " · "
    private static let maxValues = 3

    public static func text(facets: FacetSelection, bookmarksOnly: Bool, profile: LogProfile) -> String {
        let levels = facets.levels
        let levelCodes = profile.levels.filter { levels.values.contains($0.id) }.map(\.code)
            + levels.values.filter { profile.level(id: $0) == nil }.sorted()
        var parts = [part(levelCodes, isExcluding: levels.isExcluding)]
        for attribute in profile.facetAttributes {
            let filter = facets[.attribute(attribute.id)]
            parts.append(part(filter.values.sorted().map { attribute.prefix + $0 }, isExcluding: filter.isExcluding))
        }
        parts.append(bookmarksOnly ? "Bookmarks" : nil)
        let summary = parts.compactMap { $0 }.joined(separator: separator)
        return summary.isEmpty ? "All entries" : summary
    }
}

// MARK: - Private

private extension FilterSetSummary {

    static func part(_ values: [String], isExcluding: Bool) -> String? {
        guard values.isEmpty == false else { return nil }
        var text = values.prefix(maxValues).joined(separator: ", ")
        if values.count > maxValues {
            text += " +\(values.count - maxValues)"
        }
        return isExcluding ? "not \(text)" : text
    }
}
