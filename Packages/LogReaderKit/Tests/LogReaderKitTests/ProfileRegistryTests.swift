import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct ProfileRegistryTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let loader = FakeLogProfileLoader()
    private let registry: ProfileRegistry
    private let otherPath = "/tmp/other"
    private let otherRoot = URL(fileURLWithPath: "/tmp/other", isDirectory: true)

    init() {
        registry = ProfileRegistry(settings: settings, loader: loader, reloadInterval: .milliseconds(5))
    }

    @Test func startLoadsEveryProjectInTheSettingsOrder() async {
        loader.setResult(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        settings.projectRoots = [otherPath, RegistryFixtures.projectPath]

        registry.start()
        await Eventually.wait { registry.projects.count == 2 }
        registry.stop()

        #expect(registry.projects.map(\.root) == [otherRoot, RegistryFixtures.projectRoot])
        #expect(registry.projects.map(\.hasProfile) == [false, true])
        #expect(registry.projects.map(\.name) == ["other", "Example App"])
        #expect(registry.profiles == [ProfileFixtures.textTrailing])
        #expect(registry.discoveryRules == [ProfileFixtures.textTrailing.discovery].compactMap { $0 })
        #expect(registry.generation == 1)
    }

    @Test func failedProfileKeepsTheErrorAndIsSkipped() async {
        loader.setResult(.failed("The profile has no levels.", modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        settings.projectRoots = [RegistryFixtures.projectPath]

        registry.start()
        await Eventually.wait { registry.projects.isEmpty == false }
        registry.stop()

        #expect(registry.projects.first?.errorText == "The profile has no levels.")
        #expect(registry.profiles.isEmpty)
        #expect(registry.discoveryRules.isEmpty)
    }

    @Test func changedModificationDateLoadsTheProfileAgain() async {
        loader.setResult(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        settings.projectRoots = [RegistryFixtures.projectPath]
        registry.start()
        await Eventually.wait { registry.profiles.isEmpty == false }

        var changed = ProfileFixtures.textTrailing
        changed.name = "Changed"
        loader.setResult(.loaded(changed, modifiedAt: RegistryFixtures.modifiedAt.addingTimeInterval(1)), for: RegistryFixtures.projectRoot)
        await Eventually.wait { registry.profiles.first?.name == "Changed" }
        registry.stop()

        #expect(registry.generation == 2)
        #expect(loader.loadedRoots == [RegistryFixtures.projectRoot, RegistryFixtures.projectRoot])
    }

    @Test func unchangedProfileIsNotLoadedAgain() async {
        loader.setResult(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        settings.projectRoots = [RegistryFixtures.projectPath]
        registry.start()
        await Eventually.wait { registry.profiles.isEmpty == false }

        try? await Task.sleep(for: .milliseconds(50))
        registry.stop()

        #expect(loader.loadedRoots == [RegistryFixtures.projectRoot])
        #expect(registry.generation == 1)
    }

    @Test func addProjectStoresTheStandardizedPathOnce() async {
        registry.addProject(URL(fileURLWithPath: "/tmp/x/../project", isDirectory: true))
        registry.addProject(RegistryFixtures.projectRoot)
        await Eventually.wait { registry.projects.isEmpty == false }
        registry.stop()

        #expect(settings.projectRoots == [RegistryFixtures.projectPath])
        #expect(registry.projects.map(\.id) == [RegistryFixtures.projectPath])
    }

    @Test func removeProjectUpdatesTheSettingsAndTheProjects() async {
        settings.projectRoots = [otherPath, RegistryFixtures.projectPath]
        registry.start()
        await Eventually.wait { registry.projects.count == 2 }
        let generation = registry.generation

        registry.removeProject(id: otherPath)
        await Eventually.wait { registry.projects.count == 1 }
        registry.stop()

        #expect(settings.projectRoots == [RegistryFixtures.projectPath])
        #expect(registry.projects.map(\.id) == [RegistryFixtures.projectPath])
        #expect(registry.generation == generation + 1)
    }

    @Test func createExampleProfileWritesThroughTheLoaderAndReloads() async throws {
        settings.projectRoots = [RegistryFixtures.projectPath]
        registry.start()
        await Eventually.wait { registry.projects.isEmpty == false }

        loader.setResult(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        try registry.createExampleProfile(id: RegistryFixtures.projectPath)
        try registry.createExampleProfile(id: "/tmp/unknown")
        await Eventually.wait { registry.profiles.isEmpty == false }
        registry.stop()

        #expect(loader.writtenRoots == [RegistryFixtures.projectRoot])
    }

    @Test func bundleIDWinsOverTheFileName() async {
        await loadTwoProfiles()

        let profile = registry.profile(for: URL(fileURLWithPath: "/tmp/log-1.txt"), bundleID: "org.example.chat")

        #expect(profile == Self.example)
        #expect(registry.profile(forBundleID: "com.example.app") == ProfileFixtures.textTrailing)
        #expect(registry.profile(forBundleID: "org.unknown") == nil)
    }

    @Test func fileNamePrefixIsUsedWithoutAMatchingBundleID() async {
        await loadTwoProfiles()

        #expect(registry.profile(for: URL(fileURLWithPath: "/tmp/log-1.txt"), bundleID: nil) == ProfileFixtures.textTrailing)
        #expect(registry.profile(for: URL(fileURLWithPath: "/tmp/app-1.log"), bundleID: "org.unknown") == Self.example)
        #expect(registry.profile(for: URL(fileURLWithPath: "/tmp/log-1.log"), bundleID: nil) == ProfileRegistry.builtIn)
    }

    @Test func profileWithoutFileNamePrefixIsNotChosenByName() async {
        var profile = Self.example
        profile.discovery?.fileNamePrefix = ""
        loader.setResult(.loaded(profile, modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        settings.projectRoots = [RegistryFixtures.projectPath]
        registry.start()
        await Eventually.wait { registry.profiles.isEmpty == false }
        registry.stop()

        #expect(registry.profile(for: URL(fileURLWithPath: "/tmp/any.log"), bundleID: nil) == ProfileRegistry.builtIn)
        #expect(registry.profile(for: URL(fileURLWithPath: "/tmp/any.log"), bundleID: "org.example.chat") == profile)
    }

    @Test func noProfileGivesTheBuiltInProfile() {
        #expect(registry.profile(for: URL(fileURLWithPath: "/tmp/log-1.txt"), bundleID: "com.example.app") == ProfileRegistry.builtIn)
        #expect(ProfileRegistry.builtIn == LogProfile.jsonLines)
    }

    @Test func projectRootIsFoundByProfile() async {
        await loadTwoProfiles()

        #expect(registry.projectRoot(for: ProfileFixtures.textTrailing) == RegistryFixtures.projectRoot)
        #expect(registry.projectRoot(for: Self.example) == otherRoot)
        #expect(registry.projectRoot(for: ProfileRegistry.builtIn) == nil)
    }
}

// MARK: - Private

private extension ProfileRegistryTests {

    static var example: LogProfile {
        var profile = ProfileFixtures.textTrailing
        profile.name = "Other"
        profile.discovery = DiscoveryRule(bundleIDPrefix: "org.example", logsPath: "Logs", fileExtension: "log", fileNamePrefix: "app-")
        return profile
    }

    func loadTwoProfiles() async {
        loader.setResult(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        loader.setResult(.loaded(Self.example, modifiedAt: RegistryFixtures.modifiedAt), for: otherRoot)
        settings.projectRoots = [RegistryFixtures.projectPath, otherPath]
        registry.start()
        await Eventually.wait { registry.profiles.count == 2 }
        registry.stop()
    }
}
