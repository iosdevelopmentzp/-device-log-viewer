import Foundation
import LogReaderKit
import Synchronization

final class FakeAppUpdater: AppUpdater {

    struct FakeError: Error {}

    private struct State {
        var installed: InstalledBuild?
        var commits: [UpdateCommit]? = []
        var status: UpdateStatus?
        var isRunning = false
        var log = ""
        var startFails = false
        var checkCount = 0
        var startCount = 0
        var clearCount = 0
    }

    private let state: Mutex<State>

    var checkCount: Int { state.withLock { $0.checkCount } }
    var startCount: Int { state.withLock { $0.startCount } }
    var clearCount: Int { state.withLock { $0.clearCount } }

    init(installed: InstalledBuild?) {
        self.state = Mutex(State(installed: installed))
    }

    func setCommits(_ commits: [UpdateCommit]?) {
        state.withLock { $0.commits = commits }
    }

    func setStatus(_ status: UpdateStatus?) {
        state.withLock { $0.status = status }
    }

    func setRunning(_ isRunning: Bool) {
        state.withLock { $0.isRunning = isRunning }
    }

    func setLog(_ log: String) {
        state.withLock { $0.log = log }
    }

    func setStartFails(_ startFails: Bool) {
        state.withLock { $0.startFails = startFails }
    }

    func installed() -> InstalledBuild? {
        state.withLock { $0.installed }
    }

    func check(installed: InstalledBuild) throws -> [UpdateCommit] {
        try state.withLock { state in
            state.checkCount += 1
            guard let commits = state.commits else { throw FakeError() }
            return commits
        }
    }

    func start() throws {
        try state.withLock { state in
            state.startCount += 1
            guard state.startFails == false else { throw FakeError() }
        }
    }

    func status() -> UpdateStatus? {
        state.withLock { $0.status }
    }

    func clearStatus() {
        state.withLock { state in
            state.clearCount += 1
            state.status = nil
        }
    }

    func log() -> String {
        state.withLock { $0.log }
    }

    func isUpdateRunning() -> Bool {
        state.withLock { $0.isRunning }
    }
}
