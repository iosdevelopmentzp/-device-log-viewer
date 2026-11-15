import Testing
@testable import LogReaderCore

struct SortedIndicesTests {

    private let sorted = [2, 5, 9]

    @Test func lowerBoundFindsFirstNotLess() {
        #expect(SortedIndices.lowerBound(of: 0, in: sorted) == 0)
        #expect(SortedIndices.lowerBound(of: 5, in: sorted) == 1)
        #expect(SortedIndices.lowerBound(of: 6, in: sorted) == 2)
        #expect(SortedIndices.lowerBound(of: 10, in: sorted) == 3)
        #expect(SortedIndices.lowerBound(of: 1, in: []) == 0)
    }

    @Test func positionMatchesExactValueOnly() {
        #expect(SortedIndices.position(of: 9, in: sorted) == 2)
        #expect(SortedIndices.position(of: 6, in: sorted) == nil)
        #expect(SortedIndices.position(of: 10, in: sorted) == nil)
        #expect(SortedIndices.position(of: 1, in: []) == nil)
    }

    @Test func nearestPositionClampsToLastIndex() {
        #expect(SortedIndices.nearestPosition(of: 0, in: sorted) == 0)
        #expect(SortedIndices.nearestPosition(of: 6, in: sorted) == 2)
        #expect(SortedIndices.nearestPosition(of: 100, in: sorted) == 2)
        #expect(SortedIndices.nearestPosition(of: 1, in: []) == nil)
    }

    @Test func nextWrapsToFirst() {
        #expect(SortedIndices.next(after: -1, in: sorted) == 2)
        #expect(SortedIndices.next(after: 2, in: sorted) == 5)
        #expect(SortedIndices.next(after: 6, in: sorted) == 9)
        #expect(SortedIndices.next(after: 9, in: sorted) == 2)
        #expect(SortedIndices.next(after: Int.max, in: sorted) == 2)
        #expect(SortedIndices.next(after: 0, in: []) == nil)
    }

    @Test func previousWrapsToLast() {
        #expect(SortedIndices.previous(before: Int.max, in: sorted) == 9)
        #expect(SortedIndices.previous(before: 9, in: sorted) == 5)
        #expect(SortedIndices.previous(before: 3, in: sorted) == 2)
        #expect(SortedIndices.previous(before: 2, in: sorted) == 9)
        #expect(SortedIndices.previous(before: 0, in: []) == nil)
    }
}
