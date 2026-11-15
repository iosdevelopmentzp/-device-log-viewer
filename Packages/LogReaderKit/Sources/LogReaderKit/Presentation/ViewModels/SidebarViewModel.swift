import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class SidebarViewModel {

    @ObservationIgnored public weak var windowObserver: (any SidebarWindowObserver)?

    @ObservationIgnored private let workspace: Workspace
    @ObservationIgnored private let fileActions: FileActions
    @ObservationIgnored private let deleteLogFiles: DeleteLogFiles
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let contentSearch: SidebarContentSearch
    @ObservationIgnored private var isObservingSidebar = false

    public var query = "" {
        didSet { refreshContentSearch() }
    }

    public var searchesContents = false {
        didSet { refreshContentSearch() }
    }

    public var queryPrompt: String {
        searchesContents ? "Search in files" : "Filter files"
    }

    public var isSearchingContents: Bool {
        searchesContents && contentSearch.isSearching
    }

    public var showsBootedOnly: Bool {
        get { settings.sidebarShowsBootedOnly }
        set { settings.sidebarShowsBootedOnly = newValue }
    }

    public var selectedFileID: String? {
        get { workspace.session?.url.path }
        set {
            guard let newValue, newValue != workspace.session?.url.path else { return }
            openFile(URL(fileURLWithPath: newValue))
        }
    }

    public var devices: [SidebarDeviceItem] {
        let results = activeContentResults
        return filteredDevices.map { deviceItem($0, results: results) }
    }

    public var openedFiles: [SidebarFileItem] {
        workspace.sidebar.openedFiles.map { url in
            SidebarFileItem(
                url: url,
                title: url.lastPathComponent,
                sizeText: "",
                matchText: "",
                isNewest: false,
                canDelete: workspace.sidebar.device(containing: url)?.isPhysical != true
            )
        }
    }

    public var isEmpty: Bool {
        workspace.sidebar.devices.isEmpty && workspace.sidebar.openedFiles.isEmpty
    }

    public var emptyText: String {
        guard workspace.profiles.discoveryRules.isEmpty else {
            return "Run the app in a simulator, or open a log file with ⌘O."
        }
        return "Add the folder of your project in Settings → Projects (⌘,) so LogReader knows which apps to look for, or open a log file with ⌘O."
    }

    public var isFilteredEmpty: Bool {
        workspace.sidebar.devices.isEmpty == false
            && workspace.sidebar.openedFiles.isEmpty
            && filteredDevices.isEmpty
    }

    public var showsNoRunningSimulators: Bool {
        isFilteredEmpty && isQueryActive == false && showsBootedOnly
    }

    public var showsNoMatches: Bool {
        isFilteredEmpty && isQueryActive && showsNoContentMatches == false
    }

    public var showsNoContentMatches: Bool {
        isFilteredEmpty && isQueryActive && activeContentResults != nil
    }

    public var bootedCountText: String {
        let all = workspace.sidebar.devices.filter { $0.isPhysical == false }
        let booted = all.filter(\.isBooted).count
        guard booted != all.count else { return "" }
        return "\(booted) of \(all.count) simulators running"
    }

    private static let physicalDeviceSymbolName = "iphone"

    public init(
        workspace: Workspace,
        fileActions: FileActions,
        deleteLogFiles: DeleteLogFiles,
        settings: AppSettings,
        contentSearch: SidebarContentSearch
    ) {
        self.workspace = workspace
        self.fileActions = fileActions
        self.deleteLogFiles = deleteLogFiles
        self.settings = settings
        self.contentSearch = contentSearch
    }

    public func isExpanded(appID: String) -> Bool {
        guard isQueryActive == false else { return true }
        return workspace.sidebar.collapsedAppIDs.contains(appID) == false
    }

    public func clearQuery() {
        query = ""
    }

    public func showAllSimulators() {
        showsBootedOnly = false
    }

    public func setExpanded(_ isExpanded: Bool, appID: String) {
        if isExpanded {
            workspace.sidebar.collapsedAppIDs.remove(appID)
        } else {
            workspace.sidebar.collapsedAppIDs.insert(appID)
        }
    }

    public func open(_ file: SidebarFileItem) {
        openFile(file.url)
    }

    public func openInNewWindow(_ file: SidebarFileItem) {
        windowObserver?.sidebar(self, requestsNewWindowFor: file.url)
    }

    public func removeFromList(_ file: SidebarFileItem) {
        workspace.sidebar.removeOpenedFile(file.url)
    }

    public func reveal(_ file: SidebarFileItem) {
        fileActions.reveal(file.url)
    }

    public func openInDefaultApp(_ file: SidebarFileItem) {
        fileActions.openInDefaultApp(file.url)
    }

    public func copyPath(_ file: SidebarFileItem) {
        fileActions.copyPath(file.url)
    }

    public func copyFileName(_ file: SidebarFileItem) {
        fileActions.copyFileName(file.url)
    }

    public func copyFile(_ file: SidebarFileItem) {
        fileActions.copyFile(file.url)
    }

    public func saveCopy(of file: SidebarFileItem) {
        fileActions.saveCopy(of: file.url)
    }

    public func trash(_ file: SidebarFileItem) {
        guard file.canDelete else { return }
        finishTrashing(deleteLogFiles.trash(file.url))
    }

    public func showLogsFolder(_ app: SidebarAppItem) {
        fileActions.openFolder(app.logsURL)
    }

    public func copyLogsFolderPath(_ app: SidebarAppItem) {
        fileActions.copyPath(app.logsURL)
    }

    public func copyBundleID(_ app: SidebarAppItem) {
        fileActions.copyText(app.bundleID)
    }

    public func copyLatestFile(_ app: SidebarAppItem) {
        guard let url = app.newestFileURL else { return }
        fileActions.copyFile(url)
    }

    public func canDeleteOlderFiles(of app: SidebarAppItem) -> Bool {
        app.canDelete && app.files.count > 1
    }

    public func deleteOlderFiles(of app: SidebarAppItem) {
        guard app.canDelete, let container = container(id: app.id) else { return }
        finishTrashing(deleteLogFiles.deleteOlderFiles(of: container))
    }

    public func deleteAllFiles(of app: SidebarAppItem) {
        guard app.canDelete, let container = container(id: app.id) else { return }
        finishTrashing(deleteLogFiles.deleteAllFiles(of: container))
    }

    public func copyUDID(_ device: SidebarDeviceItem) {
        fileActions.copyText(device.id)
    }

    public func copyName(_ device: SidebarDeviceItem) {
        fileActions.copyText("\(device.name) (\(device.runtime))")
    }

    public func showFolder(_ device: SidebarDeviceItem) {
        fileActions.openFolder(device.folderURL)
    }

    public func deleteAllFiles(of device: SidebarDeviceItem) {
        guard device.canDelete, let simulator = workspace.sidebar.devices.first(where: { $0.id == device.id }) else { return }
        finishTrashing(deleteLogFiles.deleteAllFiles(of: simulator))
    }
}

// MARK: - Private

private extension SidebarViewModel {

    var isQueryActive: Bool {
        trimmedQuery.isEmpty == false
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var activeContentResults: [String: FileSearchResult]? {
        searchesContents ? contentSearch.results : nil
    }

    var filteredDevices: [SimulatorDevice] {
        let isWaitingForContent = searchesContents && activeContentResults == nil
        return SidebarFilter.apply(
            workspace.sidebar.devices,
            query: isWaitingForContent ? "" : query,
            bootedOnly: showsBootedOnly,
            contentResults: activeContentResults
        )
    }

    var searchableFiles: [SearchableFile] {
        SidebarFilter.apply(workspace.sidebar.devices, query: "", bootedOnly: showsBootedOnly, contentResults: nil)
            .flatMap(\.apps)
            .flatMap(\.files)
            .map { SearchableFile(url: $0.url, size: $0.size) }
    }

    func openFile(_ url: URL) {
        workspace.open(url)
        guard searchesContents, isQueryActive, let session = workspace.session else { return }
        session.setSearchMode(.find)
        session.setSearchText(trimmedQuery)
    }

    func refreshContentSearch() {
        guard searchesContents else {
            contentSearch.update(query: "", isRegex: false, files: [])
            return
        }
        contentSearch.update(query: query, isRegex: settings.searchUsesRegex, files: searchableFiles)
        observeSidebar()
    }

    func observeSidebar() {
        guard searchesContents, isObservingSidebar == false else { return }
        isObservingSidebar = true
        withObservationTracking {
            _ = workspace.sidebar.devices
            _ = settings.sidebarShowsBootedOnly
            _ = settings.searchUsesRegex
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                isObservingSidebar = false
                refreshContentSearch()
            }
        }
    }

    func container(id: String) -> AppLogContainer? {
        workspace.sidebar.devices
            .lazy
            .flatMap(\.apps)
            .first { $0.id == id }
    }

    func finishTrashing(_ urls: [URL]) {
        guard urls.isEmpty == false else { return }
        workspace.didTrash(urls)
    }

    func deviceItem(_ device: SimulatorDevice, results: [String: FileSearchResult]?) -> SidebarDeviceItem {
        let canDelete = device.isPhysical == false
        return SidebarDeviceItem(
            id: device.udid,
            name: device.name,
            runtime: device.runtime,
            subtitle: DeviceSubtitleText.subtitle(for: device),
            symbolName: device.isPhysical ? Self.physicalDeviceSymbolName : nil,
            isBooted: device.isBooted,
            folderURL: device.folderURL,
            apps: device.apps.map { appItem($0, canDelete: canDelete, results: results) },
            canDelete: canDelete,
            copyIDTitle: device.isPhysical ? "Copy Device Identifier" : "Copy Simulator UDID",
            copyNameTitle: device.isPhysical ? "Copy Device Name" : "Copy Simulator Name",
            showFolderTitle: device.isPhysical ? "Show Cache Folder in Finder" : "Show Simulator Folder in Finder"
        )
    }

    func appItem(_ app: AppLogContainer, canDelete: Bool, results: [String: FileSearchResult]?) -> SidebarAppItem {
        let newestID = app.files.first?.id
        let prefix = workspace.profiles.profile(forBundleID: app.bundleID)?.discovery?.fileNamePrefix ?? ""
        return SidebarAppItem(
            id: app.id,
            bundleID: app.bundleID,
            logsURL: app.logsURL,
            files: app.files.map { file in
                SidebarFileItem(
                    url: file.url,
                    title: LogFileTitle.title(for: file.url, prefix: prefix),
                    sizeText: FileSizeText.file(file.size),
                    matchText: MatchCountText.text(for: results?[file.url.path]),
                    isNewest: file.id == newestID,
                    canDelete: canDelete
                )
            },
            newestFileURL: app.files.first?.url,
            canDelete: canDelete
        )
    }
}
