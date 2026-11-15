import Foundation

public struct StatusBarItem: Sendable, Equatable {

    public enum Kind: Sendable {
        case loading
        case live
        case missing
    }

    public let kind: Kind
    public let entriesText: String
    public let sizeText: String
    public let isFiltering: Bool
    public let isExporting: Bool
    public let isFollowing: Bool
    public let jumpTitle: String

    public init(
        kind: Kind,
        entriesText: String,
        sizeText: String,
        isFiltering: Bool,
        isExporting: Bool,
        isFollowing: Bool,
        jumpTitle: String
    ) {
        self.kind = kind
        self.entriesText = entriesText
        self.sizeText = sizeText
        self.isFiltering = isFiltering
        self.isExporting = isExporting
        self.isFollowing = isFollowing
        self.jumpTitle = jumpTitle
    }
}
