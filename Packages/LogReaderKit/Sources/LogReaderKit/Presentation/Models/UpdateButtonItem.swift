import Foundation

public struct UpdateButtonItem: Sendable, Equatable {

    public enum Kind: Sendable {
        case available
        case running
        case failed
        case upToDate
        case updated
    }

    public let kind: Kind
    public let title: String
    public let symbolName: String?
    public let help: String
    public let opensDetails: Bool
    public let canDismiss: Bool

    public init(kind: Kind, title: String, symbolName: String?, help: String, opensDetails: Bool, canDismiss: Bool) {
        self.kind = kind
        self.title = title
        self.symbolName = symbolName
        self.help = help
        self.opensDetails = opensDetails
        self.canDismiss = canDismiss
    }
}
