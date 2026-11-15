import Foundation
import Observation

@MainActor
@Observable
public final class TimeRangeViewModel {

    public var startText = ""
    public var endText = ""

    @ObservationIgnored private let session: LogSession
    @ObservationIgnored private let settings: AppSettings

    public var hasTimeRange: Bool { session.hasTimeRange }

    public var hintText: String {
        let zone = settings.timeZoneMode == .utc ? "UTC" : "local time"
        return "Formats: 2026-10-07 22:18:54.787, 22:18:54.787, 22:18:54 or 22:18 (\(zone)). "
            + "A time without a date uses the day of the first entry. Leave End empty to show everything after Start."
    }

    public var errorText: String? {
        switch parsedRange() {
        case .success: nil
        case .failure(let error): error.text
        }
    }

    public var canApply: Bool { errorText == nil }

    private static let openEnd = Double.greatestFiniteMagnitude

    public init(session: LogSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
    }

    public func start() {
        guard let range = initialRange() else { return }
        startText = formatter.inputText(range.lowerBound)
        endText = range.upperBound < Self.openEnd ? formatter.inputText(range.upperBound) : ""
    }

    @discardableResult
    public func apply() -> Bool {
        guard case .success(let range) = parsedRange() else { return false }
        session.setTimeRange(range)
        return true
    }

    public func clear() {
        session.clearTimeRange()
    }
}

// MARK: - Private

private extension TimeRangeViewModel {

    enum ParseError: Error {
        case start
        case end
        case order

        var text: String {
            switch self {
            case .start: "Cannot read the start time"
            case .end: "Cannot read the end time"
            case .order: "Start is after end"
            }
        }
    }

    var formatter: TimeTextFormatter {
        TimeTextFormatter(timeZoneMode: settings.timeZoneMode)
    }

    var referenceTimestamp: TimeInterval? {
        firstTimestamp(in: session.visible)
    }

    func initialRange() -> ClosedRange<TimeInterval>? {
        if let range = session.filterState.timeRange {
            return range
        }
        if let range = session.timeRangeOfSelection() {
            return range
        }
        guard let first = firstTimestamp(in: session.visible),
              let last = firstTimestamp(in: session.visible.reversed()),
              first <= last else { return nil }
        return first...last
    }

    func firstTimestamp(in recordIndices: some Sequence<Int>) -> TimeInterval? {
        for index in recordIndices {
            if let timestamp = session.record(at: index)?.timestamp {
                return timestamp
            }
        }
        return nil
    }

    func parsedRange() -> Result<ClosedRange<TimeInterval>, ParseError> {
        let reference = referenceTimestamp
        guard let lower = formatter.parse(startText, near: reference) else { return .failure(.start) }
        let trimmedEnd = endText.trimmingCharacters(in: .whitespaces)
        guard trimmedEnd.isEmpty == false else { return .success(lower...Self.openEnd) }
        guard let upper = formatter.parse(trimmedEnd, near: reference) else { return .failure(.end) }
        guard lower <= upper else { return .failure(.order) }
        return .success(lower...upper)
    }
}
