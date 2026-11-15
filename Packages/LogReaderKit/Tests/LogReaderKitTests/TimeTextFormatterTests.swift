import Foundation
import Testing
@testable import LogReaderKit

struct TimeTextFormatterTests {

    private let timestamp: TimeInterval = 1_760_000_000.25
    private let fixtureTime: TimeInterval = 1_791_411_534

    @Test func utcModeFormatsTimeAndFullDateWithSuffix() {
        let formatter = TimeTextFormatter(timeZoneMode: .utc)

        #expect(formatter.time(timestamp) == "08:53:20.250")
        #expect(formatter.fullDate(timestamp) == "2025-10-09 08:53:20.250 UTC")
    }

    @Test func localModeUsesTheCurrentTimeZoneWithoutSuffix() {
        let formatter = TimeTextFormatter(timeZoneMode: .local)
        let reference = DateFormatter()
        reference.locale = Locale(identifier: "en_US_POSIX")
        reference.timeZone = .current
        reference.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        #expect(formatter.fullDate(timestamp) == reference.string(from: Date(timeIntervalSince1970: timestamp)))
        #expect(formatter.fullDate(timestamp).hasSuffix(formatter.time(timestamp)))
    }

    @Test func missingTimestampGivesEmptyText() {
        let formatter = TimeTextFormatter(timeZoneMode: .utc)

        #expect(formatter.time(nil) == "")
        #expect(formatter.fullDate(nil) == "")
    }

    @Test func utcModeParsesEveryFormat() throws {
        let formatter = TimeTextFormatter(timeZoneMode: .utc)
        let reference = fixtureTime + 100

        try Self.expect(formatter.parse("2026-10-07 22:18:54.787", near: nil), equals: fixtureTime + 0.787)
        try Self.expect(formatter.parse(" 2026-10-07 22:18:54 ", near: nil), equals: fixtureTime)
        try Self.expect(formatter.parse("22:18:54.787", near: reference), equals: fixtureTime + 0.787)
        try Self.expect(formatter.parse("22:18:54", near: reference), equals: fixtureTime)
        try Self.expect(formatter.parse("22:18", near: reference), equals: fixtureTime - 54)
    }

    @Test func localModeParsesInTheCurrentTimeZone() throws {
        let formatter = TimeTextFormatter(timeZoneMode: .local)
        let reference = DateFormatter()
        reference.locale = Locale(identifier: "en_US_POSIX")
        reference.timeZone = .current
        reference.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let expected = try #require(reference.date(from: "2026-10-07 22:18:54.787")).timeIntervalSince1970

        try Self.expect(formatter.parse("2026-10-07 22:18:54.787", near: nil), equals: expected)
        try Self.expect(formatter.parse("2026-10-07 22:18:54", near: nil), equals: expected - 0.787)
        try Self.expect(formatter.parse("22:18:54.787", near: expected), equals: expected)
        try Self.expect(formatter.parse("22:18:54", near: expected), equals: expected - 0.787)
        try Self.expect(formatter.parse("22:18", near: expected), equals: expected - 54.787)
    }

    @Test func unreadableTextGivesNil() {
        let formatter = TimeTextFormatter(timeZoneMode: .utc)

        #expect(formatter.parse("", near: fixtureTime) == nil)
        #expect(formatter.parse("yesterday", near: fixtureTime) == nil)
        #expect(formatter.parse("25:99", near: fixtureTime) == nil)
    }

    @Test func rangeTextShowsTimesDatesAndAnOpenEnd() {
        let formatter = TimeTextFormatter(timeZoneMode: .utc)
        let start = fixtureTime + 0.787

        #expect(formatter.rangeText(start...(fixtureTime + 36)) == "22:18:54.787 – 22:19:30.000")
        #expect(formatter.rangeText(start...Double.greatestFiniteMagnitude) == "22:18:54.787 – end")
        #expect(
            formatter.rangeText(fixtureTime...(fixtureTime + 86_400))
                == "2026-10-07 22:18:54.000 – 2026-10-08 22:18:54.000"
        )
        #expect(formatter.inputText(start) == "2026-10-07 22:18:54.787")
    }
}

// MARK: - Private

private extension TimeTextFormatterTests {

    static func expect(_ value: TimeInterval?, equals expected: TimeInterval) throws {
        let value = try #require(value)
        #expect(abs(value - expected) < 0.0005)
    }
}
