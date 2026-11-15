import Foundation

public enum FacetFilter<Value: Hashable & Sendable>: Sendable, Equatable {
    case all
    case only(Set<Value>)
    case except(Set<Value>)

    public var isAll: Bool {
        guard case .all = self else { return false }
        return true
    }

    public var isExcluding: Bool {
        guard case .except = self else { return false }
        return true
    }

    public var values: Set<Value> {
        switch self {
        case .all: []
        case .only(let values), .except(let values): values
        }
    }

    public func allows(_ value: Value?) -> Bool {
        switch self {
        case .all: true
        case .only(let values): value.map(values.contains) ?? false
        case .except(let values): value.map { values.contains($0) == false } ?? true
        }
    }

    public func allowsAny(of values: [Value]) -> Bool {
        switch self {
        case .all: true
        case .only(let allowed): values.contains(where: allowed.contains)
        case .except(let excluded): values.contains(where: excluded.contains) == false
        }
    }

    public func isSelected(_ value: Value) -> Bool {
        values.contains(value)
    }

    public func togglingSelection(_ value: Value) -> FacetFilter {
        switch self {
        case .all:
            return .only([value])
        case .only(let values):
            let toggled = Self.toggling(value, in: values)
            return toggled.isEmpty ? .all : .only(toggled)
        case .except(let values):
            let toggled = Self.toggling(value, in: values)
            return toggled.isEmpty ? .all : .except(toggled)
        }
    }

    public func excluding(_ value: Value) -> FacetFilter {
        guard case .except(let values) = self else { return .except([value]) }
        return .except(values.union([value]))
    }
}

// MARK: - Codable

extension FacetFilter: Codable where Value: Codable {}

// MARK: - Private

private extension FacetFilter {

    static func toggling(_ value: Value, in values: Set<Value>) -> Set<Value> {
        var values = values
        if values.contains(value) {
            values.remove(value)
        } else {
            values.insert(value)
        }
        return values
    }
}
