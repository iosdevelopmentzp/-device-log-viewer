import Foundation

public struct LogFilter: Sendable, Equatable {

    public var text: String
    public var isRegex: Bool
    public var scope: SearchScope
    public var facets: FacetSelection
    public var onlyOffsets: Set<Int>?
    public var timeRange: ClosedRange<TimeInterval>?
    public var startIndex: Int?
    public var hiddenRange: Range<Int>?
    public var hiddenOffsets: Set<Int>?
    public var extraTerms: [SearchTerm]

    public var isPassThrough: Bool {
        text.isEmpty && facets.isAll && onlyOffsets == nil && timeRange == nil && startIndex == nil
            && (hiddenRange?.isEmpty ?? true) && hiddenOffsets == nil
            && extraTerms.allSatisfy { $0.text.isEmpty }
    }

    public static let all = LogFilter(
        text: "",
        isRegex: false,
        scope: .message,
        facets: .all,
        onlyOffsets: nil,
        timeRange: nil,
        startIndex: nil,
        hiddenRange: nil,
        hiddenOffsets: nil,
        extraTerms: []
    )

    public init(
        text: String,
        isRegex: Bool,
        scope: SearchScope,
        facets: FacetSelection,
        onlyOffsets: Set<Int>?,
        timeRange: ClosedRange<TimeInterval>?,
        startIndex: Int?,
        hiddenRange: Range<Int>?,
        hiddenOffsets: Set<Int>?,
        extraTerms: [SearchTerm]
    ) {
        self.text = text
        self.isRegex = isRegex
        self.scope = scope
        self.facets = facets
        self.onlyOffsets = onlyOffsets
        self.timeRange = timeRange
        self.startIndex = startIndex
        self.hiddenRange = hiddenRange
        self.hiddenOffsets = hiddenOffsets
        self.extraTerms = extraTerms
    }
}
