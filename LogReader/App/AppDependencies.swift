import Foundation
import LogReaderKit

@MainActor
final class AppDependencies {

    let settings: AppSettings
    let settingsViewModel: SettingsViewModel
    let appearanceApplier: any AppearanceApplier
    let updateViewModel: UpdateViewModel
    let profiles: ProfileRegistry

    private let sessionFactory: any LogSessionFactory
    private let discovery: any LogDiscovery
    private let fileDialogs: any FileDialogs
    private let copyEntries: CopyEntries
    private let fileActions: FileActions
    private let deleteLogFiles: DeleteLogFiles
    private let openSource: OpenSource
    private let exportEntries: ExportEntries

    private static let readDelay: DispatchTimeInterval = .milliseconds(80)
    private static let pollInterval: DispatchTimeInterval = .seconds(1)
    private static let filterDebounce: Duration = .milliseconds(150)
    private static let scanInterval: Duration = .seconds(3)
    private static let contentSearchDebounce: Duration = .milliseconds(400)
    private static let contentSearchSizeLimit = 200_000_000
    private static let devicectlTimeout: DispatchTimeInterval = .seconds(15)
    private static let deviceScanCacheDuration: Duration = .seconds(5)
    private static let deviceMirrorInterval: DispatchTimeInterval = .milliseconds(1500)
    private static let gitTimeout: DispatchTimeInterval = .seconds(30)
    private static let updateCheckInterval: Duration = .seconds(300)
    private static let updateStatusInterval: Duration = .seconds(1)
    private static let upToDateDuration: Duration = .seconds(5)
    private static let profileReloadInterval: Duration = .seconds(3)

    init(
        settings: AppSettings,
        settingsViewModel: SettingsViewModel,
        appearanceApplier: any AppearanceApplier,
        updateViewModel: UpdateViewModel,
        profiles: ProfileRegistry,
        sessionFactory: any LogSessionFactory,
        discovery: any LogDiscovery,
        fileDialogs: any FileDialogs,
        copyEntries: CopyEntries,
        fileActions: FileActions,
        deleteLogFiles: DeleteLogFiles,
        openSource: OpenSource,
        exportEntries: ExportEntries
    ) {
        self.settings = settings
        self.settingsViewModel = settingsViewModel
        self.appearanceApplier = appearanceApplier
        self.updateViewModel = updateViewModel
        self.profiles = profiles
        self.sessionFactory = sessionFactory
        self.discovery = discovery
        self.fileDialogs = fileDialogs
        self.copyEntries = copyEntries
        self.fileActions = fileActions
        self.deleteLogFiles = deleteLogFiles
        self.openSource = openSource
        self.exportEntries = exportEntries
    }

    static func live() -> AppDependencies {
        let store: any KeyValueStore = .standardDefaults
        ToolTipDelay.register(in: store)
        WindowTabbing.enable()
        let pasteboard = SystemPasteboard()
        let fileDialogs = AppKitFileDialogs()
        let settings = AppSettings(store: store)
        let profiles = ProfileRegistry(settings: settings, loader: FileLogProfileLoader(), reloadInterval: profileReloadInterval)
        profiles.start()
        let devicesFlag = settings.connectedDevicesFlag
        let devicectl = DevicectlRunner(timeout: devicectlTimeout)
        let deviceCacheRoot = PhysicalDeviceDiscovery.defaultCacheRoot
        let sessionFactory = DefaultLogSessionFactory(
            sourceFactory: RoutingLogSourceFactory(
                fileSourceFactory: FileTailerSourceFactory(readDelay: readDelay, pollInterval: pollInterval),
                deviceCacheRoot: deviceCacheRoot,
                runner: devicectl,
                mirrorInterval: deviceMirrorInterval,
                isDeviceAccessEnabled: { devicesFlag.isOn }
            ),
            bookmarkRepository: UserDefaultsBookmarkRepository(store: store),
            debounce: filterDebounce
        )
        let updateStore = UpdateStore(
            updater: GitAppUpdater(
                directory: GitAppUpdater.defaultDirectory,
                runningAppURL: Bundle.main.bundleURL,
                installedAppURL: GitAppUpdater.defaultInstalledAppURL,
                timeout: gitTimeout
            ),
            checkInterval: updateCheckInterval,
            statusInterval: updateStatusInterval,
            upToDateDuration: upToDateDuration,
            clock: { Date() }
        )
        updateStore.start()
        let revealer = WorkspaceFileRevealer()
        let fileActions = FileActions(
            pasteboard: pasteboard,
            revealer: revealer,
            dialogs: fileDialogs,
            copier: FileManagerCopier()
        )
        return AppDependencies(
            settings: settings,
            settingsViewModel: SettingsViewModel(settings: settings, fileDialogs: fileDialogs, profiles: profiles),
            appearanceApplier: AppKitAppearanceApplier(),
            updateViewModel: UpdateViewModel(store: updateStore),
            profiles: profiles,
            sessionFactory: sessionFactory,
            discovery: CompositeLogDiscovery(
                physicalDevices: PhysicalDeviceDiscovery(
                    runner: devicectl,
                    cacheRoot: deviceCacheRoot,
                    cacheDuration: deviceScanCacheDuration
                ),
                simulators: SimulatorLogDiscovery(devicesDirectory: SimulatorLogDiscovery.defaultDevicesDirectory),
                includesPhysicalDevices: { devicesFlag.isOn }
            ),
            fileDialogs: fileDialogs,
            copyEntries: CopyEntries(pasteboard: pasteboard),
            fileActions: fileActions,
            deleteLogFiles: DeleteLogFiles(trasher: FileManagerTrasher(), dialogs: fileDialogs),
            openSource: OpenSource(
                index: FileManagerSourceFileIndex(),
                opener: ProcessSourceOpener(),
                dialogs: fileDialogs,
                profiles: profiles
            ),
            exportEntries: ExportEntries(dialogs: fileDialogs, writer: DataFileWriter(), revealer: revealer)
        )
    }

    func makeMainViewModel() -> MainViewModel {
        let workspace = Workspace(
            sidebar: SidebarStore(discovery: discovery, scanInterval: Self.scanInterval),
            sessionFactory: sessionFactory,
            settings: settings,
            profiles: profiles
        )
        return MainViewModel(
            workspace: workspace,
            sidebar: SidebarViewModel(
                workspace: workspace,
                fileActions: fileActions,
                deleteLogFiles: deleteLogFiles,
                settings: settings,
                contentSearch: SidebarContentSearch(
                    searcher: DataFileContentSearcher(),
                    debounce: Self.contentSearchDebounce,
                    sizeLimit: Self.contentSearchSizeLimit
                )
            ),
            settings: settings,
            fileDialogs: fileDialogs,
            copyEntries: copyEntries,
            openSource: openSource,
            exportEntries: exportEntries,
            attention: AppKitAppAttention()
        )
    }
}
