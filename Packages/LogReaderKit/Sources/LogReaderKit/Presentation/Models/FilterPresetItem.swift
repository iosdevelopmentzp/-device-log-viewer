import Foundation

public struct FilterPresetItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let summary: String
    public let shortcutNumber: Int?
    public let shortcutText: String

    public init(id: UUID, name: String, summary: String, shortcutNumber: Int?, shortcutText: String) {
        self.id = id
        self.name = name
        self.summary = summary
        self.shortcutNumber = shortcutNumber
        self.shortcutText = shortcutText
    }
}
