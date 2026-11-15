import Foundation
import LogReaderCore

public struct LogRowItem: Sendable, Equatable {
    public let number: Int
    public let numberText: String
    public let time: String
    public let fullDate: String
    public let delta: String
    public let levelStyle: LevelStyle?
    public let levelCode: String
    public let highlightsRow: Bool
    public let attributes: [String]
    public let message: StyledText
    public let isBookmarked: Bool
    public let isFindMatch: Bool
    public let repeatCount: Int?
    public let repeatCountText: String
    public let isGroupExpanded: Bool
    public let isGroupMember: Bool

    public init(
        number: Int,
        numberText: String,
        time: String,
        fullDate: String,
        delta: String,
        levelStyle: LevelStyle?,
        levelCode: String,
        highlightsRow: Bool,
        attributes: [String],
        message: StyledText,
        isBookmarked: Bool,
        isFindMatch: Bool,
        repeatCount: Int?,
        repeatCountText: String,
        isGroupExpanded: Bool,
        isGroupMember: Bool
    ) {
        self.number = number
        self.numberText = numberText
        self.time = time
        self.fullDate = fullDate
        self.delta = delta
        self.levelStyle = levelStyle
        self.levelCode = levelCode
        self.highlightsRow = highlightsRow
        self.attributes = attributes
        self.message = message
        self.isBookmarked = isBookmarked
        self.isFindMatch = isFindMatch
        self.repeatCount = repeatCount
        self.repeatCountText = repeatCountText
        self.isGroupExpanded = isGroupExpanded
        self.isGroupMember = isGroupMember
    }

    public func attribute(at index: Int) -> String {
        attributes.indices.contains(index) ? attributes[index] : ""
    }
}
