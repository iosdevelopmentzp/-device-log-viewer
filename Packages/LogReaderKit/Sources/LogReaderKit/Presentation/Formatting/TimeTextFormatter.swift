import Foundation

public struct TimeTextFormatter: Sendable {

    private struct Formatters: Sendable {
        let time: DateFormatter
        let dateTime: DateFormatter
        let dateTimeSeconds: DateFormatter
        let dateTimeMinutes: DateFormatter
        let day: DateFormatter

        init(timeZone: TimeZone) {
            self.time = TimeTextFormatter.makeFormatter("HH:mm:ss.SSS", timeZone: timeZone)
            self.dateTime = TimeTextFormatter.makeFormatter("yyyy-MM-dd HH:mm:ss.SSS", timeZone: timeZone)
            self.dateTimeSeconds = TimeTextFormatter.makeFormatter("yyyy-MM-dd HH:mm:ss", timeZone: timeZone)
            self.dateTimeMinutes = TimeTextFormatter.makeFormatter("yyyy-MM-dd HH:mm", timeZone: timeZone)
            self.day = TimeTextFormatter.makeFormatter("yyyy-MM-dd", timeZone: timeZone)
        }
    }

    private let timeZoneMode: TimeZoneMode

    private var formatters: Formatters {
        timeZoneMode == .utc ? Self.utc : Self.local
    }

    private static let local = Formatters(timeZone: .current)
    private static let utc = Formatters(timeZone: utcZone)
    private static let utcZone = TimeZone(identifier: "UTC") ?? .current
    private static let openEndText = "end"
    private static let rangeSeparator = " – "

    public init(timeZoneMode: TimeZoneMode) {
        self.timeZoneMode = timeZoneMode
    }

    public func time(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else { return "" }
        return formatters.time.string(from: Date(timeIntervalSince1970: timestamp))
    }

    public func fullDate(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else { return "" }
        let suffix = timeZoneMode == .utc ? " UTC" : ""
        return inputText(timestamp) + suffix
    }

    public func inputText(_ timestamp: TimeInterval) -> String {
        formatters.dateTime.string(from: Date(timeIntervalSince1970: timestamp))
    }

    public func rangeText(_ range: ClosedRange<TimeInterval>) -> String {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard upper < Double.greatestFiniteMagnitude else {
            return time(lower) + Self.rangeSeparator + Self.openEndText
        }
        guard dayText(lower) == dayText(upper) else {
            return inputText(lower) + Self.rangeSeparator + inputText(upper)
        }
        return time(lower) + Self.rangeSeparator + time(upper)
    }

    public func parse(_ text: String, near reference: TimeInterval?) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty == false else { return nil }
        let fullText = trimmed.contains("-")
            ? trimmed
            : dayText(reference ?? Date().timeIntervalSince1970) + " " + trimmed
        let candidates = [formatters.dateTime, formatters.dateTimeSeconds, formatters.dateTimeMinutes]
        for formatter in candidates {
            if let date = formatter.date(from: fullText) {
                return date.timeIntervalSince1970
            }
        }
        return nil
    }
}

// MARK: - Private

private extension TimeTextFormatter {

    static func makeFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    func dayText(_ timestamp: TimeInterval) -> String {
        formatters.day.string(from: Date(timeIntervalSince1970: timestamp))
    }
}
