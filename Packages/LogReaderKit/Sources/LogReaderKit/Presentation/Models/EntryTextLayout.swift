import Foundation

public struct EntryTextLayout: Sendable, Equatable {
    public let text: StyledText
    public let localMatches: [NSRange]
    public let links: [EntryTextLink]

    public init(text: StyledText, localMatches: [NSRange], links: [EntryTextLink]) {
        self.text = text
        self.localMatches = localMatches
        self.links = links
    }
}
