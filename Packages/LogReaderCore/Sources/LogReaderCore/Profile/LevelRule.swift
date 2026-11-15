import Foundation

public struct LevelRule: Sendable, Equatable {

    public var id: String
    public var codes: [String]
    public var title: String
    public var style: LevelStyle
    public var alerts: Bool
    public var highlightsRow: Bool
    public var colorsMessage: Bool

    public var code: String { codes.first ?? id }

    public static let standard: [LevelRule] = [
        LevelRule(id: "debug", codes: ["debug", "Debug", "DEBUG", "trace", "TRACE"], title: "Debug", style: .secondary, alerts: false, highlightsRow: false, colorsMessage: false),
        LevelRule(id: "info", codes: ["info", "Info", "INFO"], title: "Info", style: .blue, alerts: false, highlightsRow: false, colorsMessage: false),
        LevelRule(id: "notice", codes: ["notice", "Notice", "NOTICE", "default", "Default"], title: "Notice", style: .teal, alerts: false, highlightsRow: false, colorsMessage: false),
        LevelRule(id: "warning", codes: ["warning", "Warning", "WARNING", "warn", "WARN"], title: "Warning", style: .orange, alerts: false, highlightsRow: true, colorsMessage: false),
        LevelRule(id: "error", codes: ["error", "Error", "ERROR"], title: "Error", style: .red, alerts: true, highlightsRow: true, colorsMessage: true),
        LevelRule(id: "fault", codes: ["fault", "Fault", "FAULT", "critical", "Critical", "CRITICAL"], title: "Fault", style: .purple, alerts: true, highlightsRow: true, colorsMessage: true)
    ]

    public init(id: String, codes: [String], title: String, style: LevelStyle, alerts: Bool, highlightsRow: Bool, colorsMessage: Bool) {
        self.id = id
        self.codes = codes
        self.title = title
        self.style = style
        self.alerts = alerts
        self.highlightsRow = highlightsRow
        self.colorsMessage = colorsMessage
    }
}

// MARK: - Codable

extension LevelRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case id
        case codes
        case title
        case style
        case alerts
        case highlightsRow
        case colorsMessage
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        self.id = id
        self.codes = try container.decodeIfPresent([String].self, forKey: .codes) ?? [id]
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? id.capitalized
        self.style = try container.decodeIfPresent(LevelStyle.self, forKey: .style) ?? .primary
        self.alerts = try container.decodeIfPresent(Bool.self, forKey: .alerts) ?? false
        self.highlightsRow = try container.decodeIfPresent(Bool.self, forKey: .highlightsRow) ?? false
        self.colorsMessage = try container.decodeIfPresent(Bool.self, forKey: .colorsMessage) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(codes, forKey: .codes)
        try container.encode(title, forKey: .title)
        try container.encode(style, forKey: .style)
        try container.encode(alerts, forKey: .alerts)
        try container.encode(highlightsRow, forKey: .highlightsRow)
        try container.encode(colorsMessage, forKey: .colorsMessage)
    }
}
