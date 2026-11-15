import Foundation
import LogReaderCore

public struct FacetModeOption: Identifiable, Hashable, Sendable {
    public let mode: FacetMode
    public let title: String

    public var id: FacetMode { mode }

    public init(mode: FacetMode, title: String) {
        self.mode = mode
        self.title = title
    }
}
