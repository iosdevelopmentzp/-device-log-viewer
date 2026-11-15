import Foundation

public enum SortedIndices {

    public static func lowerBound(of value: Int, in sorted: [Int]) -> Int {
        var low = 0
        var high = sorted.count
        while low < high {
            let middle = (low + high) / 2
            if sorted[middle] < value {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }

    public static func position(of value: Int, in sorted: [Int]) -> Int? {
        let index = lowerBound(of: value, in: sorted)
        guard index < sorted.count, sorted[index] == value else { return nil }
        return index
    }

    public static func nearestPosition(of value: Int, in sorted: [Int]) -> Int? {
        guard sorted.isEmpty == false else { return nil }
        return min(lowerBound(of: value, in: sorted), sorted.count - 1)
    }

    public static func next(after value: Int, in sorted: [Int]) -> Int? {
        let index = upperBound(of: value, in: sorted)
        guard index < sorted.count else { return sorted.first }
        return sorted[index]
    }

    public static func previous(before value: Int, in sorted: [Int]) -> Int? {
        let index = lowerBound(of: value, in: sorted)
        guard index > 0 else { return sorted.last }
        return sorted[index - 1]
    }
}

// MARK: - Private

private extension SortedIndices {

    static func upperBound(of value: Int, in sorted: [Int]) -> Int {
        var low = 0
        var high = sorted.count
        while low < high {
            let middle = (low + high) / 2
            if sorted[middle] <= value {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }
}
