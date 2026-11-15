import Foundation
import LogReaderCore

enum ProfileFixtures {

    static let textTrailing = load("text-trailing.json")
    static let jsonLines = LogProfile.jsonLines

    static func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("docs/profiles").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        fatalError("Repository root not found from \(#filePath)")
    }

    static func load(_ name: String) -> LogProfile {
        let url = repositoryRoot().appendingPathComponent("docs/profiles").appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { fatalError("Missing profile fixture \(url.path)") }
        do {
            let profile = try JSONDecoder().decode(LogProfile.self, from: data)
            try profile.validate()
            return profile
        } catch {
            fatalError("Invalid profile fixture \(name): \(error)")
        }
    }

    static func level(_ id: String) -> LogLevel {
        guard let level = textTrailing.level(id: id) else { fatalError("Unknown level \(id)") }
        return level
    }
}
