import Foundation
import LogReaderCore

public struct LevelOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let style: LevelStyle
    public let isOn: Bool

    public init(id: String, title: String, style: LevelStyle, isOn: Bool) {
        self.id = id
        self.title = title
        self.style = style
        self.isOn = isOn
    }
}
