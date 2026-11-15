import Foundation

public struct RecentSearchItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let modeTitle: String
    public let scopeTitle: String
    public let isRegexTitle: String
    public let timeText: String
    public let isPinned: Bool
    public let pinSymbolName: String

    public init(id: UUID, text: String, modeTitle: String, scopeTitle: String, isRegexTitle: String, timeText: String, isPinned: Bool, pinSymbolName: String) {
        self.id = id
        self.text = text
        self.modeTitle = modeTitle
        self.scopeTitle = scopeTitle
        self.isRegexTitle = isRegexTitle
        self.timeText = timeText
        self.isPinned = isPinned
        self.pinSymbolName = pinSymbolName
    }
}
