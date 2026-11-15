import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct FileLogProfileLoaderTests {

    private let loader = FileLogProfileLoader()
    private let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileLogProfileLoaderTests-\(UUID().uuidString)", isDirectory: true)

    @Test func folderWithoutProfileIsMissing() {
        defer { removeRoot() }

        #expect(loader.load(projectRoot: root) == .missing)
        #expect(loader.modificationDate(projectRoot: root) == nil)
    }

    @Test func validProfileIsLoaded() throws {
        defer { removeRoot() }
        let source = ProfileFixtures.repositoryRoot().appendingPathComponent("docs/profiles/text-trailing.json")
        try write(Data(contentsOf: source))

        let result = loader.load(projectRoot: root)

        guard case .loaded(let profile, let modifiedAt) = result else {
            Issue.record("Expected a loaded profile, got \(result)")
            return
        }
        #expect(profile == ProfileFixtures.textTrailing)
        #expect(modifiedAt == loader.modificationDate(projectRoot: root))
    }

    @Test func invalidJSONGivesAReadableMessage() throws {
        defer { removeRoot() }
        try write(Data("{ not json".utf8))

        let result = loader.load(projectRoot: root)

        guard case .failed(let message, let modifiedAt) = result else {
            Issue.record("Expected a failure, got \(result)")
            return
        }
        #expect(message.contains("JSON"))
        #expect(modifiedAt != nil)
    }

    @Test func missingKeyNamesTheKey() throws {
        defer { removeRoot() }
        try write(Data(#"{"name": "App"}"#.utf8))

        #expect(loader.load(projectRoot: root) == .failed("Missing key “entry” at the top level.", modifiedAt: loader.modificationDate(projectRoot: root)))
    }

    @Test func profileThatFailsValidationGivesTheValidationMessage() throws {
        defer { removeRoot() }
        try write(Data(#"{"name": "App", "entry": {"kind": "json"}, "levels": []}"#.utf8))

        #expect(loader.load(projectRoot: root) == .failed("The profile has no levels.", modifiedAt: loader.modificationDate(projectRoot: root)))
    }

    @Test func writeExampleCreatesAProfileThatLoads() throws {
        defer { removeRoot() }

        try loader.writeExample(projectRoot: root)

        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(".logreader/profile.json").path))
        guard case .loaded(let profile, _) = loader.load(projectRoot: root) else {
            Issue.record("Expected the example to load")
            return
        }
        #expect(profile.name == "My App")
    }

    @Test func writeExampleDoesNotOverwriteAProfile() throws {
        defer { removeRoot() }
        let existing = Data(#"{"name": "Mine"}"#.utf8)
        try write(existing)

        #expect(throws: (any Error).self) { try loader.writeExample(projectRoot: root) }
        #expect(try Data(contentsOf: ProjectProfile.profileURL(in: root)) == existing)
    }

    private func write(_ data: Data) throws {
        let url = ProjectProfile.profileURL(in: root)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func removeRoot() {
        try? FileManager.default.removeItem(at: root)
    }
}
