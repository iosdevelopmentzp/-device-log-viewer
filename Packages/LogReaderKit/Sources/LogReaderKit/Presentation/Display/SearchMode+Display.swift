import Foundation

public extension SearchMode {

    var displayName: String {
        switch self {
        case .filter: "Filter"
        case .find: "Find"
        }
    }

    var prompt: String {
        switch self {
        case .filter: "Filter entries (⌘F)"
        case .find: "Find in entries (⌘F)"
        }
    }
}
