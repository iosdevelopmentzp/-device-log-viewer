import Foundation

struct JSONEntryParser: Sendable {

    struct Entry {
        let level: LogLevel?
        let timestamp: TimeInterval?
        let message: String
        let attributes: [AttributeValue]
        let fields: [Field]
    }

    struct Field {
        let key: String
        let value: String
        let isNested: Bool
    }

    let attributeCount: Int

    private let rule: JSONEntryRule
    private let attributes: [AttributeRule]
    private let time: TimeValueParser
    private let levels: LevelMatcher

    init(rule: JSONEntryRule, profile: LogProfile) {
        self.attributeCount = profile.attributes.count
        self.rule = rule
        self.attributes = profile.attributes
        self.time = TimeValueParser(rule: profile.timestamp)
        self.levels = LevelMatcher(levels: profile.levels)
    }

    func parse(_ bytes: UnsafeRawBufferPointer, range: Range<Int>, maxFields: Int) -> Entry? {
        guard let members = JSONLineScanner.members(bytes, range: range) else { return nil }
        var consumed = [Bool](repeating: false, count: members.count)

        func take(_ keys: [String]) -> JSONLineScanner.Value? {
            for key in keys {
                guard let index = members.firstIndex(where: { $0.key == key }) else { continue }
                consumed[index] = true
                return members[index].value
            }
            return nil
        }

        let message = take(rule.messageKeys)?.text(in: bytes) ?? ""
        let timestamp = take(rule.timeKeys).flatMap { time.parse($0.text(in: bytes)) }
        let level = take(rule.levelKeys).flatMap { levels.level($0.text(in: bytes)) }
        let values = attributes.map { attribute -> AttributeValue in
            guard let value = take([attribute.key]) else { return .none }
            let text = value.text(in: bytes)
            switch attribute.kind {
            case .list:
                let items = value.isNested ? (JSONLineScanner.stringItems(text) ?? []) : text.split(separator: " ").map(String.init)
                return items.isEmpty ? .none : .list(items)
            case .text:
                guard let lineKey = attribute.lineKey, let line = take([lineKey])?.text(in: bytes), line.isEmpty == false else {
                    return text.isEmpty ? .none : .text(text)
                }
                return .text("\(text):\(line)")
            }
        }
        var fields: [Field] = []
        for (index, member) in members.enumerated() where consumed[index] == false && fields.count < maxFields {
            fields.append(Field(key: member.key, value: member.value.text(in: bytes), isNested: member.value.isNested))
        }
        return Entry(level: level, timestamp: timestamp, message: message, attributes: values, fields: fields)
    }
}
