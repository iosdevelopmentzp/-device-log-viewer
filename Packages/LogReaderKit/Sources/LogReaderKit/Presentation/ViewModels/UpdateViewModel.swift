import Foundation
import Observation

@MainActor
@Observable
public final class UpdateViewModel {

    @ObservationIgnored private let store: UpdateStore

    private static let logLineCount = 200

    public var item: UpdateButtonItem? {
        switch store.state {
        case .idle:
            nil
        case .upToDate:
            UpdateButtonItem(
                kind: .upToDate,
                title: "Up to date",
                symbolName: "checkmark.circle",
                help: "The installed build has every commit of main",
                opensDetails: false,
                canDismiss: false
            )
        case .available(let commits):
            UpdateButtonItem(
                kind: .available,
                title: "Update available · \(commits.count)",
                symbolName: "arrow.down.circle",
                help: "Show the new commits in main",
                opensDetails: true,
                canDismiss: false
            )
        case .running(let phase, let startedAt):
            UpdateButtonItem(
                kind: .running,
                title: "\(phase.displayName) · \(ElapsedTimeText.text(from: startedAt, to: store.now))",
                symbolName: nil,
                help: "The app closes for a few seconds when the new build is installed",
                opensDetails: false,
                canDismiss: false
            )
        case .failed:
            UpdateButtonItem(
                kind: .failed,
                title: "Update failed",
                symbolName: "exclamationmark.triangle.fill",
                help: "Show the update log",
                opensDetails: true,
                canDismiss: false
            )
        case .updated(let shortHash):
            UpdateButtonItem(
                kind: .updated,
                title: "Updated to \(shortHash)",
                symbolName: "checkmark.circle.fill",
                help: "This build was installed by the last update",
                opensDetails: false,
                canDismiss: true
            )
        }
    }

    public var canCheck: Bool {
        store.installed != nil && store.state.isRunning == false && store.isChecking == false
    }

    public var canUpdate: Bool {
        store.installed != nil && store.state.isRunning == false
    }

    public var installedText: String {
        guard let installed = store.installed else { return "Not installed with Scripts/install.sh" }
        return "\(installed.shortCommit), \(ShortDateTimeText.text(for: installed.installedAt))"
    }

    public var statusText: String {
        guard store.installed != nil else { return "This build does not update itself" }
        switch store.state {
        case .running(let phase, let startedAt):
            return "\(phase.displayName) · \(ElapsedTimeText.text(from: startedAt, to: store.now))"
        case _ where store.isChecking:
            return "Checking…"
        case .available:
            return commitsTitle
        case .failed(let message):
            return message
        case .updated(let shortHash):
            return "Updated to \(shortHash)"
        case .idle, .upToDate:
            return store.lastCheckedAt.map { "Up to date · checked \(ShortDateTimeText.text(for: $0))" } ?? "Not checked yet"
        }
    }

    public var settingsFooter: String {
        "LogReader checks the main branch of the working copy it was installed from at launch and every few minutes. "
            + "Update Now builds main and installs it even when there are no new commits; the app closes for a few seconds."
    }

    public var commits: [UpdateCommit] {
        guard case .available(let commits) = store.state else { return [] }
        return commits
    }

    public var commitsTitle: String {
        let count = commits.count
        return count == 1 ? "1 new commit in main" : "\(count) new commits in main"
    }

    public var failureMessage: String {
        guard case .failed(let message) = store.state else { return "" }
        return message
    }

    public var logText: String {
        LogTailText.lastLines(of: store.log, count: Self.logLineCount)
    }

    public init(store: UpdateStore) {
        self.store = store
    }

    public func openDetails() {
        guard case .failed = store.state else { return }
        store.loadLog()
    }

    public func updateNow() {
        store.updateNow()
    }

    public func tryAgain() {
        store.updateNow()
    }

    public func checkNow() {
        store.checkNow()
    }

    public func dismissUpdated() {
        store.dismissUpdated()
    }
}
