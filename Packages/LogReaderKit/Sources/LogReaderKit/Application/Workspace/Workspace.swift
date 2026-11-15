import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class Workspace {

    public let sidebar: SidebarStore
    public let profiles: ProfileRegistry

    public private(set) var session: LogSession?

    @ObservationIgnored public weak var observer: (any WorkspaceObserver)?

    @ObservationIgnored private let sessionFactory: any LogSessionFactory
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var latestFileByAppID: [String: String] = [:]
    @ObservationIgnored private var isObservingProfiles = false
    @ObservationIgnored private var isRunning = false

    public init(sidebar: SidebarStore, sessionFactory: any LogSessionFactory, settings: AppSettings, profiles: ProfileRegistry) {
        self.sidebar = sidebar
        self.sessionFactory = sessionFactory
        self.settings = settings
        self.profiles = profiles
    }

    public func start() {
        isRunning = true
        sidebar.observer = self
        sidebar.start(rules: profiles.discoveryRules)
        observeProfiles()
    }

    public func stop() {
        isRunning = false
        sidebar.stop()
        session?.stop()
    }

    public func restartDiscovery() {
        sidebar.start(rules: profiles.discoveryRules)
    }

    public func open(_ url: URL) {
        guard session?.url.standardizedFileURL != url.standardizedFileURL else { return }
        openSession(url)
    }

    public func openExternal(_ url: URL) {
        sidebar.addOpenedFile(url)
        open(url)
    }

    public func didTrash(_ urls: [URL]) {
        let trashedPaths = Set(urls.map(\.standardizedFileURL.path))
        for url in sidebar.openedFiles where trashedPaths.contains(url.standardizedFileURL.path) {
            sidebar.removeOpenedFile(url)
        }
        if let session, trashedPaths.contains(session.url.standardizedFileURL.path) {
            openNewestRemainingFile(near: session.url, excluding: trashedPaths)
        }
        sidebar.rescan()
    }

    public func profile(for url: URL) -> LogProfile {
        profiles.profile(for: url, bundleID: sidebar.app(containing: url)?.bundleID)
    }
}

// MARK: - SidebarStoreObserver

extension Workspace: SidebarStoreObserver {

    public func devicesDidChange() {
        let previousLatest = latestFileByAppID
        latestFileByAppID = NewestFilePolicy.latestFiles(in: sidebar.devices)
        guard settings.followLatestFile, let session else { return }
        let newest = NewestFilePolicy.fileToOpen(
            current: session.url,
            previousLatest: previousLatest,
            devices: sidebar.devices
        )
        guard let newest else { return }
        open(newest)
    }
}

// MARK: - Private

private extension Workspace {

    func openSession(_ url: URL) {
        session?.stop()
        let newSession = sessionFactory.makeSession(
            url: url,
            profile: profile(for: url),
            searchScope: settings.searchScope,
            isRegex: settings.searchUsesRegex
        )
        session = newSession
        newSession.start()
        observer?.workspace(self, didChangeSession: newSession)
    }

    func observeProfiles() {
        guard isRunning, isObservingProfiles == false else { return }
        isObservingProfiles = true
        withObservationTracking {
            _ = profiles.generation
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                isObservingProfiles = false
                profilesDidChange()
                observeProfiles()
            }
        }
    }

    func profilesDidChange() {
        guard isRunning else { return }
        restartDiscovery()
        guard let session, session.profile != profile(for: session.url) else { return }
        openSession(session.url)
    }

    func openNewestRemainingFile(near url: URL, excluding trashedPaths: Set<String>) {
        let remaining = sidebar.app(containing: url)?.files
            .filter { trashedPaths.contains($0.url.standardizedFileURL.path) == false }
        guard let newest = remaining?.max(by: { $0.createdAt < $1.createdAt }) else { return }
        open(newest.url)
    }
}
