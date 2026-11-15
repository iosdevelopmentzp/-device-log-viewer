import Foundation

public struct ExpandedMessageItem: Sendable, Equatable {
    public let text: StyledText
    public let lineRanges: [NSRange]

    public init(text: StyledText, lineRanges: [NSRange]) {
        self.text = text
        self.lineRanges = lineRanges
    }
}
