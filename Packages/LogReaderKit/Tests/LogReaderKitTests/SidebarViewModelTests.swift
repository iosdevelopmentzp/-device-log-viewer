import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct SidebarViewModelTests {

    private let logsPath = "/tmp/device/app/Logs"
    private let discovery = FakeLogDiscovery(devices: [])
    private let sourceFactory = FakeLogSourceFactory()
    private let pasteboard = FakePasteboard()
    private let revealer = FakeFileRevealer()
    private let dialogs = FakeFileDialogs()
    private let trasher = FakeFileTrasher()
    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let searcher = FakeFileContentSearcher()
    private let workspace: Workspace

    init() async {
        let profiles = await RegistryFixtures.loaded(settings: settings, profile: ProfileFixtures.textTrailing)
        workspace = Workspace(
            sidebar: SidebarStore(discovery: discovery, scanInterval: .milliseconds(5)),
            sessionFactory: DefaultLogSessionFactory(
                sourceFactory: sourceFactory,
                bookmarkRepository: FakeBookmarkRepository(stored: [:]),
                debounce: .milliseconds(1)
            ),
            settings: settings,
            profiles: profiles
        )
    }

    @Test func devicesAreMappedToItems() async {
        let model = makeModel()
        await loadDevices()

        let device = model.devices[0]
        let app = device.apps[0]
        #expect(model.isEmpty == false)
        #expect(device.id == "A")
        #expect(device.name == "iPhone A")
        #expect(device.runtime == "iOS 26.0")
        #expect(device.isBooted)
        #expect(device.folderURL.path == "/devices/A")
        #expect(app.bundleID == "com.example.app")
        #expect(app.id == logsPath)
        #expect(app.newestFileURL?.lastPathComponent == "log-2.txt")
        #expect(app.files.map(\.title) == ["2", "1"])
        #expect(app.files.map(\.isNewest) == [true, false])
        #expect(app.files[0].sizeText == FileSizeText.file(1))
        #expect(app.files[0].id == logsPath + "/log-2.txt")
    }

    @Test func appWithoutAProfileKeepsTheFullFileNames() async {
        let model = makeModel()
        await loadDevices([
            LogFixtures.device("A", apps: [LogFixtures.app("org.other.app", logsPath: logsPath, files: ["log-2.txt"])])
        ])

        #expect(model.devices[0].apps[0].files.map(\.title) == ["log-2.txt"])
    }

    @Test func selectedFileIDOpensTheFile() {
        let model = makeModel()
        let path = logsPath + "/log-1.txt"

        #expect(model.selectedFileID == nil)
        model.selectedFileID = path

        #expect(workspace.session?.url.path == path)
        #expect(model.selectedFileID == path)
        #expect(sourceFactory.sources.count == 1)

        model.selectedFileID = path
        #expect(sourceFactory.sources.count == 1)
    }

    @Test func openInNewWindowNotifiesTheObserver() {
        let model = makeModel()
        let observer = FakeSidebarWindowObserver()
        model.windowObserver = observer
        let url = URL(fileURLWithPath: logsPath + "/log-1.txt")

        model.openInNewWindow(SidebarFileItem(url: url, title: "1", sizeText: "", matchText: "", isNewest: false, canDelete: true))

        #expect(observer.requestedURLs == [url])
        #expect(workspace.session == nil)
    }

    @Test func openedFilesAndRemoval() {
        let model = makeModel()
        let url = URL(fileURLWithPath: "/tmp/external.txt")
        #expect(model.isEmpty)

        workspace.openExternal(url)

        #expect(model.openedFiles == [SidebarFileItem(url: url, title: "external.txt", sizeText: "", matchText: "", isNewest: false, canDelete: true)])
        model.removeFromList(model.openedFiles[0])
        #expect(model.openedFiles.isEmpty)
    }

    @Test func expansionState() {
        let model = makeModel()

        #expect(model.isExpanded(appID: "x"))
        model.setExpanded(false, appID: "x")
        #expect(model.isExpanded(appID: "x") == false)
        #expect(workspace.sidebar.collapsedAppIDs == ["x"])
        model.setExpanded(true, appID: "x")
        #expect(model.isExpanded(appID: "x"))
    }

    @Test func fileAppAndDeviceActionsForwardToFileActions() async {
        let model = makeModel()
        await loadDevices()
        let device = model.devices[0]
        let app = device.apps[0]
        let file = app.files[0]

        model.open(file)
        model.reveal(file)
        model.openInDefaultApp(file)
        model.copyPath(file)
        model.copyFileName(file)
        model.copyFile(file)
        model.showLogsFolder(app)
        model.copyLogsFolderPath(app)
        model.copyBundleID(app)
        model.copyLatestFile(app)
        model.copyUDID(device)
        model.copyName(device)
        model.showFolder(device)

        #expect(workspace.session?.url == file.url)
        #expect(revealer.revealedURLs == [file.url])
        #expect(revealer.openedURLs == [file.url, app.logsURL, device.folderURL])
        #expect(pasteboard.writtenTexts == [file.url.path, "log-2.txt", logsPath, "com.example.app", "A", "iPhone A (iOS 26.0)"])
        #expect(pasteboard.writtenFileURLs == [file.url, file.url])
    }

    @Test func saveCopyUsesTheDialog() {
        let model = makeModel()
        let file = SidebarFileItem(url: URL(fileURLWithPath: "/tmp/log-a:b.txt"), title: "a:b", sizeText: "", matchText: "", isNewest: false, canDelete: true)

        model.saveCopy(of: file)

        #expect(dialogs.suggestedNames == ["log-a-b.txt"])
    }

    @Test func trashMovesTheFileAndOpensTheNextOne() async {
        let model = makeModel()
        await loadDevices()
        let app = model.devices[0].apps[0]
        model.open(app.files[0])

        model.trash(app.files[0])

        #expect(trasher.trashedURLs == [app.files[0].url])
        #expect(dialogs.confirmations.isEmpty)
        #expect(workspace.session?.url == app.files[1].url)
    }

    @Test func deleteOlderFilesOfAnAppKeepsTheNewest() async {
        let model = makeModel()
        await loadDevices()
        let app = model.devices[0].apps[0]
        dialogs.confirmAnswer = true

        #expect(model.canDeleteOlderFiles(of: app))
        model.deleteOlderFiles(of: app)

        #expect(trasher.trashedURLs == [app.files[1].url])
    }

    @Test func deleteAllFilesOfAnAppAndOfADevice() async {
        let model = makeModel()
        await loadDevices()
        let device = model.devices[0]
        dialogs.confirmAnswer = true

        model.deleteAllFiles(of: device.apps[0])
        model.deleteAllFiles(of: device)

        #expect(trasher.trashedURLs == device.apps[0].files.map(\.url) + device.apps[0].files.map(\.url))
        #expect(dialogs.confirmations.count == 2)
    }

    @Test func physicalDevicesHaveTheirOwnSubtitleSymbolAndTitles() async throws {
        let model = makeModel()
        await loadDevices([
            physicalDevice("PHONE-1", transport: .network),
            LogFixtures.device("A", apps: [LogFixtures.app("com.example.app", logsPath: logsPath, files: ["log-1.txt"])])
        ])

        let phone = try #require(model.devices.first)
        let simulator = try #require(model.devices.last)
        #expect(phone.subtitle == "iOS 27.0.1 · Wi-Fi")
        #expect(phone.symbolName == "iphone")
        #expect(phone.copyIDTitle == "Copy Device Identifier")
        #expect(phone.copyNameTitle == "Copy Device Name")
        #expect(phone.showFolderTitle == "Show Cache Folder in Finder")
        #expect(simulator.subtitle == "iOS 26.0")
        #expect(simulator.symbolName == nil)
        #expect(simulator.copyIDTitle == "Copy Simulator UDID")
        #expect(simulator.copyNameTitle == "Copy Simulator Name")
        #expect(simulator.showFolderTitle == "Show Simulator Folder in Finder")
    }

    @Test func physicalDeviceItemsCannotBeDeleted() async throws {
        let model = makeModel()
        await loadDevices([
            physicalDevice("PHONE-1", transport: .usb),
            LogFixtures.device("A", apps: [LogFixtures.app("com.example.app", logsPath: logsPath, files: ["log-2.txt", "log-1.txt"])])
        ])
        let phone = try #require(model.devices.first)
        let simulator = try #require(model.devices.last)
        dialogs.confirmAnswer = true

        #expect(phone.subtitle == "iOS 27.0.1 · USB")
        #expect(phone.canDelete == false)
        #expect(phone.apps.allSatisfy { $0.canDelete == false })
        #expect(phone.apps.flatMap(\.files).allSatisfy { $0.canDelete == false })
        #expect(simulator.canDelete)
        #expect(simulator.apps.allSatisfy { $0.canDelete })
        #expect(simulator.apps.flatMap(\.files).allSatisfy { $0.canDelete })
        #expect(model.canDeleteOlderFiles(of: phone.apps[0]) == false)

        model.trash(phone.apps[0].files[0])
        model.deleteOlderFiles(of: phone.apps[0])
        model.deleteAllFiles(of: phone.apps[0])
        model.deleteAllFiles(of: phone)

        #expect(trasher.trashedURLs.isEmpty)
        #expect(dialogs.confirmations.isEmpty)
    }

    @Test func openedDeviceFileCannotBeDeleted() async {
        let model = makeModel()
        await loadDevices([physicalDevice("PHONE-1", transport: .usb)])
        let url = URL(fileURLWithPath: "/cache/PHONE-1/com.example.app/log-2.txt")

        workspace.openExternal(url)

        #expect(model.openedFiles.map(\.canDelete) == [false])
    }

    @Test func bootedOnlyKeepsPhysicalDevicesAndTheCountIgnoresThem() async {
        let model = makeModel()
        await loadDevices([physicalDevice("PHONE-1", transport: .network), stoppedDevice("B")])

        model.showsBootedOnly = true

        #expect(model.devices.map(\.id) == ["PHONE-1"])
        #expect(model.bootedCountText == "0 of 1 simulators running")
    }

    @Test func cannotDeleteOlderFilesOfAnAppWithOneFile() {
        let model = makeModel()
        let file = SidebarFileItem(url: URL(fileURLWithPath: "/tmp/a.txt"), title: "a", sizeText: "", matchText: "", isNewest: true, canDelete: true)
        let app = SidebarAppItem(id: "x", bundleID: "x", logsURL: URL(fileURLWithPath: "/tmp"), files: [file], newestFileURL: file.url, canDelete: true)

        #expect(model.canDeleteOlderFiles(of: app) == false)
    }

    @Test func queryFiltersDevicesAndExpandsEveryApp() async {
        let model = makeModel()
        await loadDevices()
        model.setExpanded(false, appID: logsPath)

        model.query = "  LOG-1 "

        #expect(model.devices[0].apps[0].files.map(\.title) == ["1"])
        #expect(model.isExpanded(appID: logsPath))
        #expect(model.isFilteredEmpty == false)

        model.clearQuery()

        #expect(model.query.isEmpty)
        #expect(model.devices[0].apps[0].files.count == 2)
        #expect(model.isExpanded(appID: logsPath) == false)
    }

    @Test func filteredEmptyWhenTheQueryHidesEverything() async {
        let model = makeModel()
        #expect(model.isFilteredEmpty == false)
        await loadDevices()

        model.query = "nothing"

        #expect(model.devices.isEmpty)
        #expect(model.isFilteredEmpty)
        #expect(model.isEmpty == false)

        workspace.openExternal(URL(fileURLWithPath: "/tmp/external.txt"))
        #expect(model.isFilteredEmpty == false)
    }

    @Test func showsBootedOnlyReadsAndWritesTheSettings() async {
        let model = makeModel()
        await loadDevices([
            LogFixtures.device("A", apps: [LogFixtures.app("com.example.a", logsPath: "/tmp/a/Logs", files: ["log-1.txt"])]),
            stoppedDevice("B")
        ])

        #expect(model.showsBootedOnly == false)
        #expect(model.devices.map(\.id) == ["A", "B"])

        model.showsBootedOnly = true

        #expect(settings.sidebarShowsBootedOnly)
        #expect(model.devices.map(\.id) == ["A"])
        settings.sidebarShowsBootedOnly = false
        #expect(model.showsBootedOnly == false)
    }

    @Test func bootedCountText() async {
        let model = makeModel()
        #expect(model.bootedCountText == "")

        await loadDevices()
        #expect(model.bootedCountText == "")

        await loadDevices([
            LogFixtures.device("A", apps: []),
            stoppedDevice("B"),
            stoppedDevice("C")
        ])
        #expect(model.bootedCountText == "1 of 3 simulators running")
    }

    @Test func bootedOnlyWithNoRunningSimulatorShowsItsOwnEmptyState() async {
        let model = makeModel()
        await loadDevices([stoppedDevice("B")])

        model.showsBootedOnly = true

        #expect(model.devices.isEmpty)
        #expect(model.showsNoRunningSimulators)
        #expect(model.showsNoMatches == false)

        model.query = "nothing"
        #expect(model.showsNoRunningSimulators == false)
        #expect(model.showsNoMatches)

        model.clearQuery()
        model.showAllSimulators()

        #expect(model.showsBootedOnly == false)
        #expect(model.showsNoRunningSimulators == false)
        #expect(model.devices.count == 1)
    }

    @Test func contentSearchKeepsMatchingFilesAndShowsTheCount() async {
        let model = makeModel()
        await loadDevices()
        searcher.setResult(.count(12), for: logsPath + "/log-2.txt")
        model.query = "payment"
        #expect(model.queryPrompt == "Filter files")
        #expect(model.devices.isEmpty)

        model.searchesContents = true

        #expect(model.queryPrompt == "Search in files")
        #expect(model.devices[0].apps[0].files.count == 2)
        await Eventually.wait { model.isSearchingContents == false && model.devices.first?.apps.first?.files.count == 1 }
        let file = model.devices[0].apps[0].files[0]
        #expect(file.title == "2")
        #expect(file.matchText == "12 matches")
        #expect(Set(searcher.calls) == [logsPath + "/log-2.txt", logsPath + "/log-1.txt"])
        #expect(Set(searcher.queries) == ["payment"])

        model.searchesContents = false

        #expect(model.devices.isEmpty)
    }

    @Test func openInContentModeSetsTheSessionSearch() async throws {
        let model = makeModel()
        await loadDevices()
        searcher.setResult(.count(1), for: logsPath + "/log-1.txt")
        model.searchesContents = true
        model.query = "  Payment "
        await Eventually.wait { model.devices.first?.apps.first?.files.count == 1 }
        let file = model.devices[0].apps[0].files[0]
        #expect(file.matchText == "1 match")

        model.open(file)

        let session = try #require(workspace.session)
        #expect(session.url == file.url)
        #expect(session.filterState.searchMode == .find)
        #expect(session.filterState.searchText == "Payment")
    }

    @Test func noContentMatchesHasItsOwnEmptyState() async {
        let model = makeModel()
        await loadDevices()
        model.searchesContents = true
        model.query = "missing"

        await Eventually.wait { model.isSearchingContents == false && model.devices.isEmpty }

        #expect(model.showsNoContentMatches)
        #expect(model.showsNoMatches == false)

        model.searchesContents = false
        #expect(model.showsNoContentMatches == false)
        #expect(model.showsNoMatches)
    }

    private func stoppedDevice(_ udid: String) -> SimulatorDevice {
        SimulatorDevice(
            udid: udid,
            name: "iPhone \(udid)",
            runtime: "iOS 26.0",
            isBooted: false,
            folderURL: URL(fileURLWithPath: "/devices/\(udid)", isDirectory: true),
            apps: [LogFixtures.app("com.example.\(udid)", logsPath: "/tmp/\(udid)/Logs", files: ["log-1.txt"])],
            kind: .simulator
        )
    }

    private func physicalDevice(_ udid: String, transport: DeviceTransport) -> SimulatorDevice {
        SimulatorDevice(
            udid: udid,
            name: "Test Phone",
            runtime: "iOS 27.0.1",
            isBooted: true,
            folderURL: URL(fileURLWithPath: "/cache/\(udid)", isDirectory: true),
            apps: [LogFixtures.app("com.example.app", logsPath: "/cache/\(udid)/com.example.app", files: ["log-2.txt", "log-1.txt"])],
            kind: .physical(transport)
        )
    }

    private func makeModel() -> SidebarViewModel {
        SidebarViewModel(
            workspace: workspace,
            fileActions: FileActions(pasteboard: pasteboard, revealer: revealer, dialogs: dialogs, copier: FakeFileCopier()),
            deleteLogFiles: DeleteLogFiles(trasher: trasher, dialogs: dialogs),
            settings: settings,
            contentSearch: SidebarContentSearch(searcher: searcher, debounce: .milliseconds(1), sizeLimit: 1_000)
        )
    }

    private func loadDevices() async {
        await loadDevices([
            LogFixtures.device("A", apps: [LogFixtures.app("com.example.app", logsPath: logsPath, files: ["log-2.txt", "log-1.txt"])])
        ])
    }

    private func loadDevices(_ devices: [SimulatorDevice]) async {
        discovery.setDevices(devices)
        workspace.start()
        await Eventually.wait { workspace.sidebar.devices == devices }
        workspace.stop()
    }
}
