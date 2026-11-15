import Foundation

public struct LogEntryDetails: Sendable, Equatable {

    public struct Field: Sendable, Equatable {
        public let key: String
        public let value: String
        public let prettyValue: String?

        public init(key: String, value: String, prettyValue: String?) {
            self.key = key
            self.value = value
            self.prettyValue = prettyValue
        }
    }

    public let message: String
    public let fields: [Field]

    public static func parse(_ text: String, record: LogRecord, profile: LogProfile) -> LogEntryDetails {
        if let entry = jsonEntry(text, record: record, profile: profile) {
            let fields = entry.fields.map { Field(key: $0.key, value: $0.value, prettyValue: $0.isNested ? prettyJSON($0.value) : nil) }
            return LogEntryDetails(message: entry.message, fields: fields)
        }
        let parts = messageAndBody(text, record: record, profile: profile)
        let bodyLines = parts.body.isEmpty ? [] : parts.body.split(separator: "\n", omittingEmptySubsequences: false)
        return LogEntryDetails(message: parts.message, fields: parseFields(bodyLines, indent: profile.fields.indent))
    }

    public static func messageAndBody(_ text: String, record: LogRecord, profile: LogProfile) -> (message: String, body: String) {
        Array(text.utf8).withUnsafeBytes { LogEntryText(profile: profile).messageAndBody($0, record: record) }
    }

    static func prettyJSON(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, first == "{" || first == "[" else { return nil }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let pretty = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
              ) else { return nil }
        let result = String(decoding: pretty, as: UTF8.self)
        return result == trimmed ? nil : result
    }
}

// MARK: - Private

private extension LogEntryDetails {

    static func jsonEntry(_ text: String, record: LogRecord, profile: LogProfile) -> JSONEntryParser.Entry? {
        guard record.isStructured, case .json(let rule) = profile.entry else { return nil }
        let parser = JSONEntryParser(rule: rule, profile: profile)
        var bytes = Array(text.utf8)
        return bytes.withUnsafeMutableBytes { buffer in
            parser.parse(UnsafeRawBufferPointer(buffer), range: 0..<buffer.count, maxFields: Int.max)
        }
    }

    static func parseFields(_ lines: [Substring], indent: Int) -> [Field] {
        let indentation = String(repeating: " ", count: indent)
        var fields: [Field] = []
        var currentKey: String?
        var currentValue: [Substring] = []

        func flush() {
            guard let key = currentKey else { return }
            let value = currentValue.joined(separator: "\n")
            fields.append(Field(key: key, value: value, prettyValue: prettyJSON(value)))
        }

        for line in lines {
            if let (key, value) = fieldStart(line, indentation: indentation) {
                flush()
                currentKey = key
                currentValue = value.isEmpty ? [] : [value]
            } else if currentKey != nil {
                currentValue.append(line.hasPrefix(indentation) ? line.dropFirst(indent) : line)
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty == false {
                currentKey = ""
                currentValue = [line]
            }
        }
        flush()
        return fields
    }

    static func fieldStart(_ line: Substring, indentation: String) -> (String, Substring)? {
        guard line.hasPrefix(indentation), let first = line.dropFirst(indentation.count).first else { return nil }
        guard first != " ", first != "\"", first != "{", first != "[", first != "}", first != "]" else { return nil }
        let body = line.dropFirst(indentation.count)
        guard let colon = body.firstIndex(of: ":") else { return nil }
        let key = body[body.startIndex..<colon]
        guard key.isEmpty == false, key.count <= 64, key.contains("\"") == false else { return nil }
        let afterColon = body[body.index(after: colon)...]
        guard afterColon.isEmpty || afterColon.first == " " else { return nil }
        return (String(key), afterColon.drop(while: { $0 == " " }))
    }
}
