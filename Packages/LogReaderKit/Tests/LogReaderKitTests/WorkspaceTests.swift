import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct WorkspaceTests {

    private let logsPath = "/tmp/device/app/Logs"
    private let discovery = FakeLogDiscovery(devices: [])
    private let sourceFactory = FakeLogSourceFactory()
    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let observer = FakeWorkspaceObserver()
    private let loader = FakeLogProfileLoader()
    private let profiles: ProfileRegistry

    init() {
        profiles = ProfileRegistry(settings: settings, loader: loader, reloadInterval: .milliseconds(5))
    }

    private func makeWorkspace() -> Workspace {
        let workspace = Workspace(
            sidebar: SidebarStore(discovery: discovery, scanInterval: .milliseconds(5)),
            sessionFactory: DefaultLogSessionFactory(
                sourceFactory: sourceFactory,
                bookmarkRepository: FakeBookmarkRepository(stored: [:]),
                debounce: .milliseconds(1)
            ),
            settings: settings,
            profiles: profiles
        )
        workspace.observer = observer
        return workspace
    }

    @Test func openReplacesTheSession() {
        let workspace = makeWorkspace()
        let first = URL(fileURLWithPath: "/tmp/1.txt")
        let second = URL(fileURLWithPath: "/tmp/2.txt")

        workspace.open(first)
        workspace.open(first)
        workspace.open(second)

        #expect(workspace.session?.url == second)
        #expect(sourceFactory.sources.map(\.url) == [first, second])
        #expect(sourceFactory.sources[0].isStopped)
        #expect(sourceFactory.sources[1].isStopped == false)
        #expect(observer.sessions.map(\.url) == [first, second])
    }

    @Test func newSessionUsesTheStoredSearchScope() {
        settings.searchScope = SearchScope(ids: ["message", "level"])
        let workspace = makeWorkspace()

        workspace.open(URL(fileURLWithPath: "/tmp/1.txt"))

        #expect(workspace.session?.filterState.searchScope == SearchScope(ids: ["message", "level"]))
    }

    @Test func newSessionUsesTheStoredRegexSetting() {
        settings.searchUsesRegex = true
        let workspace = makeWorkspace()

        workspace.open(URL(fileURLWithPath: "/tmp/1.txt"))

        #expect(workspace.session?.filterState.isRegex == true)
    }

    @Test func externalFileIsAddedToTheList() {
        let workspace = makeWorkspace()
        let url = URL(fileURLWithPath: "/tmp/external.txt")

        workspace.openExternal(url)

        #expect(workspace.sidebar.openedFiles == [url])
        #expect(workspace.session?.url == url)
    }

    @Test func followsTheNewestFile() async {
        discovery.setDevices([device(files: ["old.txt"])])
        let workspace = makeWorkspace()
        workspace.start()
        await Eventually.wait { workspace.sidebar.devices.isEmpty == false }
        workspace.open(URL(fileURLWithPath: logsPath + "/old.txt"))

        discovery.setDevices([device(files: ["new.txt", "old.txt"])])
        await Eventually.wait { workspace.session?.url.lastPathComponent == "new.txt" }
        workspace.stop()

        #expect(sourceFactory.sources.count == 2)
    }

    @Test func doesNotFollowWhenTheSettingIsOff() async {
        settings.followLatestFile = false
        discovery.setDevices([device(files: ["old.txt"])])
        let workspace = makeWorkspace()
        workspace.start()
        await Eventually.wait { workspace.sidebar.devices.isEmpty == false }
        workspace.open(URL(fileURLWithPath: logsPath + "/old.txt"))

        discovery.setDevices([device(files: ["new.txt", "old.txt"])])
        await Eventually.wait { workspace.sidebar.devices.first?.apps.first?.files.count == 2 }
        workspace.stop()

        #expect(workspace.session?.url.lastPathComponent == "old.txt")
    }

    @Test func discoveryUsesTheRulesOfTheLoadedProfiles() async {
        let workspace = makeWorkspace()
        workspace.start()
        await Eventually.wait { discovery.scannedRules.isEmpty == false }
        #expect(discovery.scannedRules.first == [])

        loadTextTrailingProfile()
        await Eventually.wait { discovery.scannedRules.last == Self.textTrailingRules }
        workspace.stop()
        profiles.stop()
    }

    @Test func fileWithoutAProfileUsesTheBuiltInProfile() {
        let workspace = makeWorkspace()

        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))

        #expect(workspace.session?.profile == ProfileRegistry.builtIn)
        #expect(sourceFactory.profiles == [ProfileRegistry.builtIn])
    }

    @Test func fileNamePrefixChoosesTheProfile() async {
        loadTextTrailingProfile()
        await Eventually.wait { profiles.profiles.isEmpty == false }
        profiles.stop()
        let workspace = makeWorkspace()

        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        workspace.open(URL(fileURLWithPath: "/tmp/other.log"))

        #expect(sourceFactory.profiles == [ProfileFixtures.textTrailing, ProfileRegistry.builtIn])
    }

    @Test func bundleIDChoosesTheProfileOfADeviceFile() async {
        loadTextTrailingProfile()
        await Eventually.wait { profiles.profiles.isEmpty == false }
        discovery.setDevices([device(files: ["app.log"])])
        let workspace = makeWorkspace()
        workspace.start()
        await Eventually.wait { workspace.sidebar.devices.isEmpty == false }

        workspace.open(URL(fileURLWithPath: logsPath + "/app.log"))
        workspace.stop()
        profiles.stop()

        #expect(workspace.profile(for: URL(fileURLWithPath: logsPath + "/app.log")) == ProfileFixtures.textTrailing)
        #expect(workspace.session?.profile == ProfileFixtures.textTrailing)
    }

    @Test func sessionIsOpenedAgainWhenItsProfileChanges() async {
        let workspace = makeWorkspace()
        workspace.start()
        let url = URL(fileURLWithPath: "/tmp/log-1.txt")
        workspace.open(url)
        #expect(workspace.session?.profile == ProfileRegistry.builtIn)

        loadTextTrailingProfile()
        await Eventually.wait { workspace.session?.profile == ProfileFixtures.textTrailing }
        workspace.stop()
        profiles.stop()

        #expect(workspace.session?.url == url)
        #expect(sourceFactory.sources.count == 2)
        #expect(sourceFactory.sources[0].isStopped)
        #expect(observer.sessions.count == 2)
    }

    @Test func sessionIsKeptWhenAnotherProfileChanges() async {
        let workspace = makeWorkspace()
        workspace.start()
        workspace.open(URL(fileURLWithPath: "/tmp/other.log"))
        let generation = profiles.generation

        loadTextTrailingProfile()
        await Eventually.wait { profiles.generation > generation }
        await Eventually.wait { discovery.scannedRules.last == Self.textTrailingRules }
        workspace.stop()
        profiles.stop()

        #expect(sourceFactory.sources.count == 1)
        #expect(workspace.session?.profile == ProfileRegistry.builtIn)
    }

    @Test func trashingTheOpenFileOpensTheNewestRemainingFile() async {
        discovery.setDevices([device(files: ["new.txt", "middle.txt", "old.txt"])])
        let workspace = makeWorkspace()
        workspace.start()
        await Eventually.wait { workspace.sidebar.devices.isEmpty == false }
        workspace.open(URL(fileURLWithPath: logsPath + "/new.txt"))

        workspace.didTrash([URL(fileURLWithPath: logsPath + "/new.txt"), URL(fileURLWithPath: logsPath + "/middle.txt")])
        workspace.stop()

        #expect(workspace.session?.url.lastPathComponent == "old.txt")
    }

    @Test func trashingTheLastFileKeepsTheSession() async {
        discovery.setDevices([device(files: ["only.txt"])])
        let workspace = makeWorkspace()
        workspace.start()
        await Eventually.wait { workspace.sidebar.devices.isEmpty == false }
        let url = URL(fileURLWithPath: logsPath + "/only.txt")
        workspace.open(url)

        workspace.didTrash([url])
        workspace.stop()

        #expect(workspace.session?.url == url)
        #expect(sourceFactory.sources.count == 1)
    }

    @Test func trashingAnotherFileKeepsTheSessionAndRemovesOpenedFiles() async {
        discovery.setDevices([device(files: ["new.txt", "old.txt"])])
        let workspace = makeWorkspace()
        workspace.start()
        await Eventually.wait { workspace.sidebar.devices.isEmpty == false }
        let external = URL(fileURLWithPath: "/tmp/external.txt")
        workspace.openExternal(external)
        workspace.open(URL(fileURLWithPath: logsPath + "/new.txt"))

        workspace.didTrash([URL(fileURLWithPath: logsPath + "/old.txt"), external])
        workspace.stop()

        #expect(workspace.session?.url.lastPathComponent == "new.txt")
        #expect(workspace.sidebar.openedFiles.isEmpty)
        #expect(sourceFactory.sources.count == 2)
    }
}

// MARK: - Private

private extension WorkspaceTests {

    static let textTrailingRules = ProfileFixtures.textTrailing.discovery.map { [$0] } ?? []

    func loadTextTrailingProfile() {
        loader.setResult(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        settings.projectRoots = [RegistryFixtures.projectPath]
        profiles.start()
    }

    func device(files: [String]) -> SimulatorDevice {
        LogFixtures.device("A", apps: [LogFixtures.app("com.example.a", logsPath: logsPath, files: files)])
    }
}
