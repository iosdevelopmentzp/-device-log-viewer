import Foundation

public extension LogProfile {

    static let jsonLines = LogProfile(
        name: "JSON Lines",
        discovery: nil,
        framing: .lines(joinsUnrecognizedLines: false),
        entry: .json(.standard),
        timestamp: .iso8601,
        levels: LevelRule.standard,
        attributes: [
            .text("subsystem", title: "Subsystem", columnWidth: 150),
            .text("category", title: "Category", columnWidth: 110),
            .source("source", title: "Source", key: "file", lineKey: "line", columnWidth: 170),
            AttributeRule(id: "process", title: "Process", kind: .text, prefix: "", facet: true, searchable: true, role: nil, key: "process", lineKey: nil, columnWidth: 110, hidden: true),
            AttributeRule(id: "thread", title: "Thread", kind: .text, prefix: "", facet: false, searchable: false, role: nil, key: "thread", lineKey: nil, columnWidth: 80, hidden: true)
        ],
        fields: .standard,
        source: .standard
    )
}
