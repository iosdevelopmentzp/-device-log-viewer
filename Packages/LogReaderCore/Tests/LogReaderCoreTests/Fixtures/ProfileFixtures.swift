import Foundation
import LogReaderCore

enum ProfileFixtures {

    static let textTrailing = load("text-trailing.json")
    static let textLeading = load("text-leading.json")
    static let regex = load("regex.json")
    static let jsonLines = LogProfile.jsonLines

    static let header = "{\"v\":1,\"sep\":\"\\u001e\"}\n"
    static let terminator = "\n\u{1E}"

    static func profilesDirectory() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
        }
        return url.appendingPathComponent("docs/profiles", isDirectory: true)
    }

    static func load(_ name: String) -> LogProfile {
        let url = profilesDirectory().appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { fatalError("Missing profile fixture \(url.path)") }
        do {
            let profile = try JSONDecoder().decode(LogProfile.self, from: data)
            try profile.validate()
            return profile
        } catch {
            fatalError("Invalid profile fixture \(name): \(error)")
        }
    }

    static func content(_ text: String, profile: LogProfile) throws -> LogContent {
        var indexer = LogIndexer(profile: profile)
        var content = LogContent(profile: profile)
        guard let batch = indexer.consume(Data(text.utf8)) else { throw FixtureError.noBatch }
        content.append(batch)
        return content
    }

    static func records(_ text: String, profile: LogProfile) throws -> [LogRecord] {
        try content(text, profile: profile).records
    }

    enum FixtureError: Error {
        case noBatch
    }
}
