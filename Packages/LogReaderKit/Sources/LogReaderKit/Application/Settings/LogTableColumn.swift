import Foundation
import LogReaderCore

public struct LogTableColumn: Hashable, Sendable, Codable, RawRepresentable {

    public let rawValue: String

    public static let number = LogTableColumn(rawValue: "number")
    public static let time = LogTableColumn(rawValue: "time")
    public static let delta = LogTableColumn(rawValue: "delta")
    public static let level = LogTableColumn(rawValue: "level")
    public static let message = LogTableColumn(rawValue: "message")

    private static let fixed: [LogTableColumn] = [.number, .time, .delta, .level, .message]

    public var canHide: Bool { self != .message }

    public var isFixed: Bool { Self.fixed.contains(self) }

    public var attributeID: String? { isFixed ? nil : rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func attribute(_ id: String) -> LogTableColumn {
        LogTableColumn(rawValue: id)
    }

    public static func all(in profile: LogProfile) -> [LogTableColumn] {
        [.number, .time, .delta, .level] + profile.attributes.map { .attribute($0.id) } + [.message]
    }
}
