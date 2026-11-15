import Foundation
import Observation

@MainActor
@Observable
public final class UpdateStore {

    public private(set) var state: UpdateState = .idle
    public private(set) var installed: InstalledBuild?
    public private(set) var now = Date.distantPast
    public private(set) var log = ""
    public private(set) var lastCheckedAt: Date?
    public private(set) var isChecking = false

    @ObservationIgnored private let updater: any AppUpdater
    @ObservationIgnored private let checkInterval: Duration
    @ObservationIgnored private let statusInterval: Duration
    @ObservationIgnored private let upToDateDuration: Duration
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var launchTask: Task<Void, Never>?
    @ObservationIgnored private var checkTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var upToDateTask: Task<Void, Never>?
    @ObservationIgnored private var startRequestedAt: Date?

    private static let startGrace: TimeInterval = 10
    private static let stoppedMessage = "The update stopped"
    private static let notStartedMessage = "Could not start the update"
    private static let defaultFailureMessage = "The update failed"

    public init(
        updater: any AppUpdater,
        checkInterval: Duration,
        statusInterval: Duration,
        upToDateDuration: Duration,
        clock: @escaping () -> Date
    ) {
        self.updater = updater
        self.checkInterval = checkInterval
        self.statusInterval = statusInterval
        self.upToDateDuration = upToDateDuration
        self.clock = clock
    }

    public func start() {
        guard launchTask == nil else { return }
        let updater = updater
        launchTask = Task { [weak self] in
            let launch = await Task.detached(priority: .utility) {
                (installed: updater.installed(), isRunning: updater.isUpdateRunning(), status: updater.status())
            }.value
            guard let self else { return }
            guard let installed = launch.installed else { return }
            self.installed = installed
            if handle(launch.status, isRunning: launch.isRunning) {
                startStatusLoop()
            }
            startCheckLoop()
        }
    }

    public func stop() {
        launchTask?.cancel()
        checkTask?.cancel()
        statusTask?.cancel()
        upToDateTask?.cancel()
    }

    public func checkNow() {
        Task { await check(isManual: true) }
    }

    public func updateNow() {
        guard installed != nil, state.isRunning == false else { return }
        let requestedAt = clock()
        startRequestedAt = requestedAt
        now = requestedAt
        state = .running(.fetching, startedAt: requestedAt)
        let updater = updater
        Task { [weak self] in
            let didStart = await Task.detached(priority: .utility) {
                updater.clearStatus()
                return (try? updater.start()) != nil
            }.value
            guard let self else { return }
            guard didStart else {
                state = .failed(message: Self.notStartedMessage)
                return
            }
            startStatusLoop()
        }
    }

    public func dismissUpdated() {
        guard case .updated = state else { return }
        state = .idle
    }

    public func loadLog() {
        let updater = updater
        Task { [weak self] in
            let log = await Task.detached(priority: .utility) { updater.log() }.value
            guard let self else { return }
            self.log = log
        }
    }
}

// MARK: - Private

private extension UpdateStore {

    var isStarting: Bool {
        guard let startRequestedAt else { return false }
        return now.timeIntervalSince(startRequestedAt) < Self.startGrace
    }

    func startCheckLoop() {
        checkTask?.cancel()
        let checkInterval = checkInterval
        checkTask = Task { [weak self] in
            while Task.isCancelled == false {
                guard let self else { return }
                await check(isManual: false)
                try? await Task.sleep(for: checkInterval)
            }
        }
    }

    func check(isManual: Bool) async {
        guard let installed, state.isRunning == false else { return }
        let updater = updater
        isChecking = true
        let commits = await Task.detached(priority: .utility) { () -> [UpdateCommit]? in
            guard updater.isUpdateRunning() == false else { return nil }
            return try? updater.check(installed: installed)
        }.value
        isChecking = false
        guard let commits else { return }
        lastCheckedAt = clock()
        apply(commits, isManual: isManual)
    }

    func apply(_ commits: [UpdateCommit], isManual: Bool) {
        switch state {
        case .running:
            return
        case .failed where isManual == false:
            return
        default:
            break
        }
        if commits.isEmpty == false {
            state = .available(commits)
        } else if isManual {
            showUpToDate()
        } else if case .available = state {
            state = .idle
        }
    }

    func showUpToDate() {
        state = .upToDate
        upToDateTask?.cancel()
        let upToDateDuration = upToDateDuration
        upToDateTask = Task { [weak self] in
            try? await Task.sleep(for: upToDateDuration)
            guard let self, Task.isCancelled == false else { return }
            guard state == .upToDate else { return }
            state = .idle
        }
    }

    func startStatusLoop() {
        statusTask?.cancel()
        let updater = updater
        let statusInterval = statusInterval
        statusTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: statusInterval)
                let reading = await Task.detached(priority: .utility) {
                    let isRunning = updater.isUpdateRunning()
                    return (isRunning: isRunning, status: updater.status())
                }.value
                guard let self, Task.isCancelled == false else { return }
                guard handle(reading.status, isRunning: reading.isRunning) else { return }
            }
        }
    }

    func handle(_ status: UpdateStatus?, isRunning: Bool) -> Bool {
        now = clock()
        guard let status else {
            guard isRunning || isStarting else {
                if state.isRunning {
                    state = .failed(message: Self.stoppedMessage)
                }
                return false
            }
            return true
        }
        switch status.phase {
        case .fetching, .building, .installing:
            guard isRunning || isStarting else {
                state = .failed(message: Self.stoppedMessage)
                return false
            }
            state = .running(status.phase, startedAt: status.startedAt)
            return true
        case .done:
            finish(commit: status.commit)
            return false
        case .failed:
            state = .failed(message: status.message ?? Self.defaultFailureMessage)
            return false
        }
    }

    func finish(commit: String?) {
        let updater = updater
        Task.detached(priority: .utility) { updater.clearStatus() }
        guard let installed, commit == installed.commit else {
            state = .idle
            return
        }
        state = .updated(shortHash: installed.shortCommit)
    }
}
