import Foundation

public enum SearchMode: String, CaseIterable, Sendable {
    case filter
    case find
}

// MARK: - Codable

extension SearchMode: Codable {}
