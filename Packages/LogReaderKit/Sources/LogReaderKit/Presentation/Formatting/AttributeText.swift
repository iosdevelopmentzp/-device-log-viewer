import Foundation
import LogReaderCore

public enum AttributeText {

    public static func text(_ value: AttributeValue, rule: AttributeRule) -> String {
        switch value {
        case .none: ""
        case .text(let text): text
        case .list(let items): items.map { rule.prefix + $0 }.joined(separator: " ")
        }
    }

    public static func texts(of record: LogRecord, profile: LogProfile) -> [String] {
        profile.attributes.enumerated().map { index, rule in
            text(profile.value(of: record, attribute: index), rule: rule)
        }
    }
}
