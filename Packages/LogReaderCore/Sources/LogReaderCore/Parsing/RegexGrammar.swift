import Foundation

struct RegexGrammar: @unchecked Sendable {

    private let regex: NSRegularExpression
    private let groupNames: Set<String>
    private let attributes: [AttributeRule]
    private let time: TimeValueParser
    private let levels: LevelMatcher

    private static let messageGroup = "message"
    private static let timeGroup = "time"
    private static let levelGroup = "level"
    private static let groupNamePattern = try! NSRegularExpression(pattern: "\\(\\?<([A-Za-z][A-Za-z0-9_]*)>")

    init?(pattern: String, profile: LogProfile) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return nil }
        self.regex = regex
        let patternRange = NSRange(pattern.startIndex..., in: pattern)
        self.groupNames = Set(
            Self.groupNamePattern.matches(in: pattern, range: patternRange).compactMap { match in
                Range(match.range(at: 1), in: pattern).map { String(pattern[$0]) }
            }
        )
        self.attributes = profile.attributes
        self.time = TimeValueParser(rule: profile.timestamp)
        self.levels = LevelMatcher(levels: profile.levels)
    }

    func parse(_ bytes: UnsafeRawBufferPointer, lineStart: Int, lineEnd: Int) -> LogHeaderLine? {
        let line = String(decoding: UnsafeRawBufferPointer(rebasing: bytes[lineStart..<lineEnd]), as: UTF8.self)
        let fullRange = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: fullRange),
              let messageRange = group(Self.messageGroup, in: match, line: line) else { return nil }

        let level = group(Self.levelGroup, in: match, line: line).flatMap { levels.level(String(line[$0])) }
        let timestamp = group(Self.timeGroup, in: match, line: line).flatMap { time.parse(String(line[$0])) }
        let values = attributes.map { attribute -> AttributeValue in
            guard let range = group(attribute.id, in: match, line: line) else { return .none }
            let text = String(line[range])
            guard attribute.kind == .list else { return .text(text) }
            let items = text.split(separator: " ").map { item -> String in
                let item = String(item)
                return attribute.prefix.isEmpty == false && item.hasPrefix(attribute.prefix)
                    ? String(item.dropFirst(attribute.prefix.count)) : item
            }
            return items.isEmpty ? .none : .list(items)
        }

        let messageStart = lineStart + line.utf8.distance(from: line.startIndex, to: messageRange.lowerBound)
        let messageEnd = lineStart + line.utf8.distance(from: line.startIndex, to: messageRange.upperBound)
        let metadataRange = messageStart == lineStart ? messageEnd..<lineEnd : lineStart..<messageStart
        return LogHeaderLine(
            level: level,
            timestamp: timestamp,
            attributes: values,
            messageRange: messageStart..<messageEnd,
            metadataRange: metadataRange
        )
    }
}

// MARK: - Private

private extension RegexGrammar {

    func group(_ name: String, in match: NSTextCheckingResult, line: String) -> Range<String.Index>? {
        guard groupNames.contains(name) else { return nil }
        let range = match.range(withName: name)
        guard range.location != NSNotFound else { return nil }
        return Range(range, in: line)
    }
}
