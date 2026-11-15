import Foundation

public enum AttributeValue: Hashable, Sendable {
    case none
    case text(String)
    case list([String])

    public var values: [String] {
        switch self {
        case .none: []
        case .text(let value): [value]
        case .list(let values): values
        }
    }

    public var text: String? {
        switch self {
        case .none: nil
        case .text(let value): value
        case .list(let values): values.isEmpty ? nil : values.joined(separator: " ")
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .none: true
        case .text(let value): value.isEmpty
        case .list(let values): values.isEmpty
        }
    }
}
