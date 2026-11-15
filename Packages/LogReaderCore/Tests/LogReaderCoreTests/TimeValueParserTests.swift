import Foundation
import Testing
@testable import LogReaderCore

struct TimeValueParserTests {

    @Test func patternParsesFixedWidthFields() throws {
        let parser = TimeValueParser(rule: .pattern("yyyy-MM-dd HH:mm:ss.SSS", timeZone: "UTC"))
        #expect(parser.fixedWidth == 23)
        let expected = try #require(LogIndexerTests.utcDate("2026-10-07 22:18:54.787"))
        #expect(abs((parser.parse("2026-10-07 22:18:54.787") ?? 0) - expected.timeIntervalSince1970) < 0.0005)
        #expect(parser.parse("2026-13-07 22:18:54.787") == nil)
        #expect(parser.parse("2026-10-07T22:18:54.787") == nil)
        #expect(parser.parse("2026-10-07 22:18:54") == nil)
    }

    @Test func patternAppliesTheTimeZone() throws {
        let parser = TimeValueParser(rule: .pattern("dd.MM.yy HH:mm", timeZone: "Europe/Kyiv"))
        let expected = try #require(LogIndexerTests.date("2026-07-01 12:30:00.000", zone: "Europe/Kyiv"))
        #expect(parser.parse("01.07.26 12:30") == expected.timeIntervalSince1970)
    }

    @Test func patternWithTimeOnlyCountsFromEpochDay() {
        let parser = TimeValueParser(rule: .pattern("HH:mm:ss", timeZone: "UTC"))
        #expect(parser.parse("01:02:03") == 3_723)
    }

    @Test func compileRejectsUnknownLetters() {
        #expect(TimestampParser.compile("yyyy QQ") == nil)
        #expect(TimestampParser.compile("--") == nil)
        #expect(TimestampParser.compile("HH:mm:ss,SS") != nil)
    }

    @Test func iso8601AcceptsCommonForms() throws {
        let parser = TimeValueParser(rule: .iso8601)
        #expect(parser.fixedWidth == nil)
        #expect(parser.parse("2026-10-07T22:18:54Z") == 1_791_411_534)
        #expect(parser.parse("2026-10-07T22:18:54.5Z") == 1_791_411_534.5)
        #expect(parser.parse("2026-10-07T23:18:54+01:00") == 1_791_411_534)
        #expect(parser.parse("2026-10-07T23:18:54+0100") == 1_791_411_534)
        #expect(parser.parse("2026-10-07T21:18:54-01") == 1_791_411_534)
        #expect(parser.parse("2026-10-07 22:18:54") == 1_791_411_534)
        #expect(parser.parse("2026-10-07T22:18:54X") == nil)
        #expect(parser.parse("1791411534") == 1_791_411_534)
        #expect(parser.parse("1791411534000") == 1_791_411_534)
        #expect(parser.parse("garbage") == nil)
    }

    @Test func epochKindsScaleTheNumber() {
        #expect(TimeValueParser(rule: TimestampRule(kind: .epochSeconds, format: nil, timeZone: "UTC")).parse("1791411534.25") == 1_791_411_534.25)
        #expect(TimeValueParser(rule: TimestampRule(kind: .epochMilliseconds, format: nil, timeZone: "UTC")).parse("1791411534250") == 1_791_411_534.25)
        #expect(TimeValueParser(rule: TimestampRule(kind: .epochSeconds, format: nil, timeZone: "UTC")).parse("1.2.3") == nil)
    }
}
