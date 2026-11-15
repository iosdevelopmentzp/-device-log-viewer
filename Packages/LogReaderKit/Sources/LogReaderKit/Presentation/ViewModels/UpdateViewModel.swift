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
        store.installed != nil && store.state.isRunning == false
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
