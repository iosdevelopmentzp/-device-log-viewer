import Foundation
import Testing
@testable import LogReaderCore

struct LogProfileTests {

    @Test func exampleProfilesDecodeAndValidate() throws {
        let textTrailing = ProfileFixtures.textTrailing
        #expect(textTrailing.name == "Example App")
        #expect(textTrailing.discovery?.bundleIDPrefix == "com.example")
        #expect(textTrailing.framing == .header)
        #expect(textTrailing.levels.map(\.id) == ["debug", "info", "notice", "warning", "error", "fault"])
        #expect(textTrailing.attributes.map(\.id) == ["tags", "category", "source"])
        #expect(textTrailing.sourceAttributeIndex == 2)
        #expect(textTrailing.alertLevels == [LogLevel(index: 4), LogLevel(index: 5)])
        #expect(textTrailing.rule(of: LogLevel(index: 4))?.code == "ERR")
        #expect(textTrailing.level(id: "fault") == LogLevel(index: 5))
        #expect(textTrailing.level(id: "nope") == nil)
        #expect(textTrailing.source == .standard)

        #expect(ProfileFixtures.textLeading.framing == .lines(joinsUnrecognizedLines: true))
        #expect(ProfileFixtures.jsonLines.entry.isJSON)
        try ProfileFixtures.jsonLines.validate()
    }

    @Test func codableRoundTrip() throws {
        for profile in [ProfileFixtures.textTrailing, ProfileFixtures.textLeading, ProfileFixtures.regex, ProfileFixtures.jsonLines] {
            let data = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(LogProfile.self, from: data)
            #expect(decoded == profile)
        }
    }

    @Test func minimalProfileGetsDefaults() throws {
        let json = "{\"name\":\"Mini\",\"entry\":{\"kind\":\"json\"}}"
        let profile = try JSONDecoder().decode(LogProfile.self, from: Data(json.utf8))

        #expect(profile.framing == .lines(joinsUnrecognizedLines: false))
        #expect(profile.timestamp == .iso8601)
        #expect(profile.levels == LevelRule.standard)
        #expect(profile.attributes.isEmpty)
        #expect(profile.fields.indent == 2)
        #expect(profile.source.editorCommand == "/usr/bin/xed")
        #expect(profile.source.editorArguments(path: "/a/b.swift", line: 12) == ["--line", "12", "/a/b.swift"])
        #expect(profile.source.editorArguments(path: "/a/b.swift", line: nil) == ["--line", "/a/b.swift"])
        try profile.validate()
    }

    @Test func jsonKeysAcceptStringOrList() throws {
        let json = "{\"name\":\"K\",\"entry\":{\"kind\":\"json\",\"message\":\"msg\",\"time\":[\"ts\",\"t\"]}}"
        let profile = try JSONDecoder().decode(LogProfile.self, from: Data(json.utf8))
        guard case .json(let rule) = profile.entry else {
            Issue.record("Expected a JSON entry rule")
            return
        }
        #expect(rule.messageKeys == ["msg"])
        #expect(rule.timeKeys == ["ts", "t"])
        #expect(rule.levelKeys == JSONEntryRule.standard.levelKeys)
    }

    @Test func validationReportsErrors() {
        var profile = ProfileFixtures.textTrailing
        profile.levels[1].id = "debug"
        #expect(throws: LogProfileError.duplicateLevel("debug")) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.attributes[0].id = "level"
        #expect(throws: LogProfileError.reservedAttribute("level")) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.entry = .trailing([.delimited("missing", open: "[", close: "]", pattern: nil, requires: nil)])
        #expect(throws: LogProfileError.unknownAttribute("missing")) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.entry = .trailing([.list("tags", prefix: "#", requires: "nothing")])
        #expect(throws: LogProfileError.unknownTokenReference("nothing")) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.entry = .regex("(?<time>x")
        #expect(throws: LogProfileError.self) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.entry = .regex("(?<time>x)")
        #expect(throws: LogProfileError.regexWithoutMessageGroup) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.timestamp = .pattern("yyyy-MM-dd QQ", timeZone: "UTC")
        #expect(throws: LogProfileError.invalidTimestampFormat("yyyy-MM-dd QQ")) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.timestamp = .pattern("yyyy", timeZone: "Mars/Olympus")
        #expect(throws: LogProfileError.unknownTimeZone("Mars/Olympus")) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.framing = .separator("ab")
        #expect(throws: LogProfileError.invalidSeparator) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.attributes[0].role = .source
        #expect(throws: LogProfileError.severalSourceAttributes) { try profile.validate() }

        profile = ProfileFixtures.textTrailing
        profile.fields.indent = 0
        #expect(throws: LogProfileError.invalidFieldIndent) { try profile.validate() }
    }

    @Test func discoveryRuleMatchesBundleIDAndFileName() {
        let rule = DiscoveryRule(bundleIDPrefix: "com.example", logsPath: "Logs", fileExtension: "txt", fileNamePrefix: "log-")
        #expect(rule.matches(bundleID: "com.example.app"))
        #expect(rule.matches(bundleID: "org.other") == false)
        #expect(rule.matches(fileName: "log-2026.txt"))
        #expect(rule.matches(fileName: "log-2026.json") == false)
        #expect(rule.matches(fileName: "other.txt") == false)

        let open = DiscoveryRule(bundleIDPrefix: "", logsPath: "Logs", fileExtension: "", fileNamePrefix: "")
        #expect(open.matches(bundleID: "anything"))
        #expect(open.matches(fileName: "anything.bin"))
    }

    @Test func facetColumnValuesComeFromTheProfile() throws {
        let profile = ProfileFixtures.textTrailing
        let text = ProfileFixtures.header
            + "Socket connected #network #auth INF [websocket] [Sockets:10] 2026-10-07 22:18:54.000\n\u{1E}"
        let record = try #require(ProfileFixtures.records(text, profile: profile).first)

        #expect(FacetColumn.level.values(of: record, profile: profile) == ["info"])
        #expect(FacetColumn.attribute("tags").values(of: record, profile: profile) == ["network", "auth"])
        #expect(FacetColumn.attribute("category").values(of: record, profile: profile) == ["websocket"])
        #expect(FacetColumn.attribute("source").values(of: record, profile: profile) == ["Sockets"])
        #expect(FacetColumn.all(in: profile) == [.level, .attribute("tags"), .attribute("category"), .attribute("source")])

        let plain = try #require(ProfileFixtures.records("plain line\n", profile: profile).first)
        for column in FacetColumn.all(in: profile) {
            #expect(column.values(of: plain, profile: profile).isEmpty)
        }
    }

    @Test func searchScopeOptionsFollowTheProfile() {
        var scope = SearchScope.message
        #expect(SearchScope.optionIDs(in: ProfileFixtures.textTrailing) == ["message", "tags", "category", "source", "level"])
        scope.toggle("tags")
        scope.toggle("level")
        #expect(scope.sorted(in: ProfileFixtures.textTrailing) == ["message", "tags", "level"])
        #expect(scope.attributeIDs == ["tags"])
        #expect(scope.includesLevel)
        scope.toggle("level")
        #expect(scope.includesLevel == false)
        #expect(SearchScope.optionIDs(in: ProfileFixtures.jsonLines) == ["message", "subsystem", "category", "source", "process", "level"])
    }
}
