import Foundation
import LogReaderCore

public enum EntryJSONEncoder {

    fileprivate enum Value {
        case literal(String)
        case array([Value])
        case object([(key: String, value: Value)])
    }

    private static let indentUnit = "  "
    private static let textFieldKey = "text"
    private static let timeStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    public static func json(number: Int, record: LogRecord, text: String, profile: LogProfile) -> String {
        let details = LogEntryDetails.parse(text, record: record, profile: profile)
        let time = record.timestamp.map { timeStyle.format(Date(timeIntervalSince1970: $0)) }
        let attributes = profile.attributes.enumerated().map { index, attribute -> (key: String, value: Value) in
            let value = profile.value(of: record, attribute: index)
            switch attribute.kind {
            case .list: return (attribute.id, .array(value.values.map(string)))
            case .text: return (attribute.id, optionalString(value.text))
            }
        }
        let entry = Value.object([
            ("number", .literal(String(number))),
            ("level", optionalString(record.level.flatMap(profile.rule(of:))?.id)),
            ("time", optionalString(time))
        ] + attributes + [
            ("message", string(details.message)),
            ("fields", fields(details.fields))
        ])
        return render(entry, indent: "")
    }
}

// MARK: - Private

private extension EntryJSONEncoder {

    static func fields(_ fields: [LogEntryDetails.Field]) -> Value {
        var counts: [String: Int] = [:]
        var pairs: [(key: String, value: Value)] = []
        for field in fields {
            let baseKey = field.key.isEmpty ? textFieldKey : field.key
            let count = (counts[baseKey] ?? 0) + 1
            counts[baseKey] = count
            let key = count == 1 ? baseKey : "\(baseKey)#\(count)"
            pairs.append((key, fieldValue(field)))
        }
        return .object(pairs.sorted { $0.key < $1.key })
    }

    static func fieldValue(_ field: LogEntryDetails.Field) -> Value {
        let candidate = (field.prettyValue ?? field.value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = candidate.first, first == "{" || first == "[",
              let object = try? JSONSerialization.jsonObject(with: Data(candidate.utf8)) else {
            return string(field.value)
        }
        return value(from: object)
    }

    static func value(from object: Any) -> Value {
        switch object {
        case let dictionary as [String: Any]:
            return .object(dictionary.keys.sorted().map { ($0, value(from: dictionary[$0] ?? NSNull())) })
        case let array as [Any]:
            return .array(array.map(value(from:)))
        default:
            return .literal(fragment(object))
        }
    }

    static func string(_ text: String) -> Value {
        .literal(fragment(text))
    }

    static func optionalString(_ text: String?) -> Value {
        text.map(string) ?? .literal("null")
    }

    static func fragment(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.fragmentsAllowed, .withoutEscapingSlashes]
        ) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }

    static func render(_ value: Value, indent: String) -> String {
        let inner = indent + indentUnit
        switch value {
        case .literal(let text):
            return text
        case .array(let items):
            guard items.isEmpty == false else { return "[]" }
            let lines = items.map { inner + render($0, indent: inner) }
            return "[\n" + lines.joined(separator: ",\n") + "\n" + indent + "]"
        case .object(let pairs):
            guard pairs.isEmpty == false else { return "{}" }
            let lines = pairs.map { inner + fragment($0.key) + " : " + render($0.value, indent: inner) }
            return "{\n" + lines.joined(separator: ",\n") + "\n" + indent + "}"
        }
    }
}
