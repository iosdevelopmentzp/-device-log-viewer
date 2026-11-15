import Foundation
import LogReaderCore

public struct EntryHeaderItem: Sendable, Equatable {

    public struct MetadataRow: Sendable, Equatable, Identifiable {
        public let title: String
        public let value: String
        public let isSource: Bool

        public var id: String { title }

        public init(title: String, value: String, isSource: Bool) {
            self.title = title
            self.value = value
            self.isSource = isSource
        }
    }

    public let number: Int
    public let numberText: String
    public let levelStyle: LevelStyle?
    public let levelTitle: String
    public let isBookmarked: Bool
    public let metadata: [MetadataRow]
    public let sizeText: String
    public let hasSource: Bool
    public let openSourceTitle: String

    public init(
        number: Int,
        numberText: String,
        levelStyle: LevelStyle?,
        levelTitle: String,
        isBookmarked: Bool,
        metadata: [MetadataRow],
        sizeText: String,
        hasSource: Bool,
        openSourceTitle: String
    ) {
        self.number = number
        self.numberText = numberText
        self.levelStyle = levelStyle
        self.levelTitle = levelTitle
        self.isBookmarked = isBookmarked
        self.metadata = metadata
        self.sizeText = sizeText
        self.hasSource = hasSource
        self.openSourceTitle = openSourceTitle
    }
}
