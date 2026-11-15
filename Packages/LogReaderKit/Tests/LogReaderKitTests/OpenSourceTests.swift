import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct OpenSourceTests {

    private struct OpenError: Error {}

    private let index = FakeSourceFileIndex()
    private let opener = FakeSourceOpener()
    private let dialogs = FakeFileDialogs()
    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let root = RegistryFixtures.projectRoot
    private let profile = ProfileFixtures.textTrailing

    @Test func recordWithoutSourcePresentsAnError() async {
        let openSource = await loadedOpenSource()

        openSource.open(Self.record(source: nil), profile: profile)

        #expect(Self.descriptions(dialogs.presentedErrors) == ["This entry has no source file."])
        #expect(index.roots.isEmpty)
        #expect(opener.opened.isEmpty)
    }

    @Test func profileWithoutProjectAsksToAddTheProject() {
        let openSource = OpenSource(index: index, opener: opener, dialogs: dialogs, profiles: RegistryFixtures.empty(settings: settings))

        openSource.open(Self.record(source: "ApiService:229"), profile: profile)

        #expect(Self.descriptions(dialogs.presentedErrors) == ["Add the project folder in Settings → Projects."])
        #expect(index.roots.isEmpty)
        #expect(opener.opened.isEmpty)
    }

    @Test func fileNotFoundNamesTheFileAndTheRoot() async {
        let openSource = await loadedOpenSource()

        openSource.open(Self.record(source: "ApiService:229"), profile: profile)

        #expect(Self.descriptions(dialogs.presentedErrors) == ["ApiService.swift was not found under /tmp/project"])
        #expect(index.roots.map(\.path) == ["/tmp/project"])
        #expect(index.preferredExtensions == ["swift"])
        #expect(opener.opened.isEmpty)
    }

    @Test func fileNotFoundKeepsAnExtensionFromTheLog() async {
        let openSource = await loadedOpenSource()

        openSource.open(Self.record(source: "Client.kt:12"), profile: profile)

        #expect(Self.descriptions(dialogs.presentedErrors) == ["Client.kt was not found under /tmp/project"])
    }

    @Test func severalCandidatesOpenTheFirstOne() async {
        let openSource = await loadedOpenSource()
        let first = root.appendingPathComponent("Api/ApiService.swift")
        index.locations["ApiService"] = [first, root.appendingPathComponent("Old/Api/ApiService.swift")]

        openSource.open(Self.record(source: "ApiService:229"), profile: profile)

        #expect(opener.opened.map(\.0) == [first])
        #expect(opener.opened.map(\.1) == [229])
        #expect(opener.editors == [profile.source])
        #expect(dialogs.presentedErrors.isEmpty)
    }

    @Test func sourceWithoutLineOpensWithoutLine() async {
        let openSource = await loadedOpenSource()
        let url = root.appendingPathComponent("ApiService.swift")
        index.locations["ApiService"] = [url]

        openSource.open(Self.record(source: "ApiService"), profile: profile)

        #expect(opener.opened.map(\.0) == [url])
        #expect(opener.opened.map(\.1) == [nil])
    }

    @Test func openerErrorIsPresented() async {
        let openSource = await loadedOpenSource()
        index.locations["ApiService"] = [root.appendingPathComponent("ApiService.swift")]
        opener.errorToThrow = OpenError()

        openSource.open(Self.record(source: "ApiService:229"), profile: profile)

        #expect(dialogs.presentedErrors.count == 1)
        guard case .openFailed = dialogs.presentedErrors.first as? OpenSourceError else {
            Issue.record("Expected openFailed")
            return
        }
    }

    private func loadedOpenSource() async -> OpenSource {
        let profiles = await RegistryFixtures.loaded(settings: settings, profile: profile)
        return OpenSource(index: index, opener: opener, dialogs: dialogs, profiles: profiles)
    }

    private static func record(source: String?) -> LogRecord {
        LogFixtures.record(message: "", level: nil, tags: [], category: nil, source: source)
    }

    private static func descriptions(_ errors: [any Error]) -> [String] {
        errors.map(\.localizedDescription)
    }
}
