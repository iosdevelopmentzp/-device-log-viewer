import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class ProfileRegistry {

    public private(set) var projects: [ProjectProfile] = []
    public private(set) var generation = 0

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let loader: any LogProfileLoader
    @ObservationIgnored private let reloadInterval: Duration
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    public static let builtIn = LogProfile.jsonLines

    public var profiles: [LogProfile] { projects.compactMap(\.profile) }

    public var discoveryRules: [DiscoveryRule] { profiles.compactMap(\.discovery) }

    public init(settings: AppSettings, loader: any LogProfileLoader, reloadInterval: Duration) {
        self.settings = settings
        self.loader = loader
        self.reloadInterval = reloadInterval
    }

    public func start() {
        reloadTask?.cancel()
        let loader = loader
        let reloadInterval = reloadInterval
        reloadTask = Task { [weak self] in
            while Task.isCancelled == false {
                guard let self else { return }
                let roots = settings.projectRoots.map { URL(fileURLWithPath: $0, isDirectory: true) }
                let stale = roots.filter { root in
                    guard let project = projects.first(where: { $0.root == root }) else { return true }
                    return project.modifiedAt != loader.modificationDate(projectRoot: root)
                }
                let removed = projects.contains { roots.contains($0.root) == false }
                if stale.isEmpty == false || removed {
                    let loaded = await Task.detached(priority: .utility) {
                        stale.map { Self.project(for: $0, loader: loader) }
                    }.value
                    guard Task.isCancelled == false else { return }
                    apply(loaded, roots: roots)
                }
                try? await Task.sleep(for: reloadInterval)
            }
        }
    }

    public func stop() {
        reloadTask?.cancel()
        reloadTask = nil
    }

    public func reload() {
        projects = []
        start()
    }

    public func addProject(_ root: URL) {
        let path = root.standardizedFileURL.path
        guard settings.projectRoots.contains(path) == false else { return }
        settings.projectRoots.append(path)
        start()
    }

    public func removeProject(id: String) {
        settings.projectRoots.removeAll { $0 == id }
        start()
    }

    public func createExampleProfile(id: String) throws {
        guard let project = projects.first(where: { $0.id == id }) else { return }
        try loader.writeExample(projectRoot: project.root)
        reload()
    }

    public func profile(forBundleID bundleID: String) -> LogProfile? {
        profiles.first { $0.discovery?.matches(bundleID: bundleID) == true }
    }

    public func profile(for url: URL, bundleID: String?) -> LogProfile {
        if let bundleID, let profile = profile(forBundleID: bundleID) {
            return profile
        }
        let fileName = url.lastPathComponent
        let byName = profiles.first { profile in
            guard let discovery = profile.discovery else { return false }
            return discovery.fileNamePrefix.isEmpty == false && discovery.matches(fileName: fileName)
        }
        return byName ?? Self.builtIn
    }

    public func projectRoot(for profile: LogProfile) -> URL? {
        projects.first { $0.profile == profile }?.root
    }
}

// MARK: - Private

private extension ProfileRegistry {

    func apply(_ loaded: [ProjectProfile], roots: [URL]) {
        let byRoot = Dictionary((projects + loaded).map { ($0.root, $0) }, uniquingKeysWith: { _, reloaded in reloaded })
        let next = roots.compactMap { byRoot[$0] }
        guard next != projects else { return }
        projects = next
        generation += 1
    }

    nonisolated static func project(for root: URL, loader: any LogProfileLoader) -> ProjectProfile {
        switch loader.load(projectRoot: root) {
        case .missing:
            ProjectProfile(root: root, profile: nil, errorText: nil, modifiedAt: nil)
        case .loaded(let profile, let modifiedAt):
            ProjectProfile(root: root, profile: profile, errorText: nil, modifiedAt: modifiedAt)
        case .failed(let message, let modifiedAt):
            ProjectProfile(root: root, profile: nil, errorText: message, modifiedAt: modifiedAt)
        }
    }
}
