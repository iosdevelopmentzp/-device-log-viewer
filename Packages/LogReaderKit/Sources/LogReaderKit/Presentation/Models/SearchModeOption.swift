import Foundation

public struct SearchModeOption: Identifiable, Hashable, Sendable {
    public let mode: SearchMode
    public let title: String

    public var id: SearchMode { mode }

    public init(mode: SearchMode, title: String) {
        self.mode = mode
        self.title = title
    }
}
