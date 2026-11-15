import Foundation
import Testing
@testable import LogReaderKit

@MainActor
struct UpdateStoreTests {

    private let clock = ManualClock(now: UpdateFixtures.startedAt.addingTimeInterval(30))

    @Test func developmentBuildNeverChecks() async {
        let updater = FakeAppUpdater(installed: nil)
        updater.setCommits(UpdateFixtures.commits)
        let store = makeStore(updater)

        store.start()
        try? await Task.sleep(for: .milliseconds(30))
        store.stop()

        #expect(store.state == .idle)
        #expect(store.installed == nil)
        #expect(updater.checkCount == 0)
    }

    @Test func newCommitsMakeAnUpdateAvailable() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setCommits(UpdateFixtures.commits)
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { store.state == .available(UpdateFixtures.commits) }
        store.stop()

        #expect(store.installed == UpdateFixtures.installed)
    }

    @Test func noNewCommitsKeepTheButtonHidden() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { updater.checkCount >= 2 }
        store.stop()

        #expect(store.state == .idle)
    }

    @Test func availableUpdateDisappearsWhenTheCheckFindsNothing() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setCommits(UpdateFixtures.commits)
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { store.state == .available(UpdateFixtures.commits) }
        updater.setCommits([])
        await Eventually.wait { store.state == .idle }
        store.stop()
    }

    @Test func failedCheckKeepsTheState() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setCommits(UpdateFixtures.commits)
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { store.state == .available(UpdateFixtures.commits) }
        updater.setCommits(nil)
        let count = updater.checkCount
        await Eventually.wait { updater.checkCount > count + 1 }
        store.stop()

        #expect(store.state == .available(UpdateFixtures.commits))
    }

    @Test func manualCheckShowsUpToDateForAWhile() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        let store = makeStore(updater, upToDateDuration: .milliseconds(50))
        store.start()
        await Eventually.wait { store.installed != nil }

        store.checkNow()
        await Eventually.wait { store.state == .upToDate }
        await Eventually.wait { store.state == .idle }
        store.stop()
    }

    @Test func doneAfterLaunchShowsTheNewCommitOnce() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.done, commit: UpdateFixtures.installedCommit, message: nil))
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { store.state == .updated(shortHash: "4bf0b5d") }
        await Eventually.wait { updater.clearCount == 1 }

        store.dismissUpdated()
        store.stop()

        #expect(store.state == .idle)
        #expect(updater.status() == nil)
    }

    @Test func doneForAnotherCommitIsIgnored() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.done, commit: "0000000", message: nil))
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { updater.clearCount == 1 }
        store.stop()

        #expect(store.state == .idle)
    }

    @Test func failedStatusAfterLaunchShowsTheFailure() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.failed, commit: nil, message: "The build failed. See the log"))
        updater.setCommits(UpdateFixtures.commits)
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { store.state == .failed(message: "The build failed. See the log") }
        await Eventually.wait { updater.checkCount >= 2 }
        store.stop()

        #expect(store.state == .failed(message: "The build failed. See the log"))
    }

    @Test func runningPhaseWithoutAScriptMeansTheUpdateDied() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.building, commit: nil, message: nil))
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { store.state == .failed(message: "The update stopped") }
        store.stop()
    }

    @Test func runningUpdateAfterLaunchFollowsTheStatus() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.building, commit: nil, message: nil))
        updater.setRunning(true)
        updater.setCommits(UpdateFixtures.commits)
        let store = makeStore(updater)

        store.start()
        await Eventually.wait { store.state == .running(.building, startedAt: UpdateFixtures.startedAt) }
        #expect(updater.checkCount == 0)

        updater.setStatus(UpdateFixtures.status(.installing, commit: nil, message: nil))
        await Eventually.wait { store.state == .running(.installing, startedAt: UpdateFixtures.startedAt) }

        updater.setRunning(false)
        updater.setStatus(UpdateFixtures.status(.failed, commit: nil, message: "Could not get the changes"))
        await Eventually.wait { store.state == .failed(message: "Could not get the changes") }
        store.stop()
    }

    @Test func updateNowStartsTheScriptAndFollowsThePhases() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setCommits(UpdateFixtures.commits)
        let store = makeStore(updater)
        store.start()
        await Eventually.wait { store.state == .available(UpdateFixtures.commits) }

        store.updateNow()
        #expect(store.state == .running(.fetching, startedAt: clock.now))
        await Eventually.wait { updater.startCount == 1 }
        #expect(updater.clearCount == 1)

        updater.setRunning(true)
        updater.setStatus(UpdateFixtures.status(.building, commit: nil, message: nil))
        await Eventually.wait { store.state == .running(.building, startedAt: UpdateFixtures.startedAt) }

        clock.advance(by: 80)
        await Eventually.wait { store.now == clock.now }
        store.stop()
    }

    @Test func scriptThatNeverWritesAStatusFailsAfterTheGracePeriod() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        let store = makeStore(updater)
        store.start()
        await Eventually.wait { store.installed != nil }

        store.updateNow()
        await Eventually.wait { updater.startCount == 1 }
        try? await Task.sleep(for: .milliseconds(20))
        #expect(store.state.isRunning)

        clock.advance(by: 11)
        await Eventually.wait { store.state == .failed(message: "The update stopped") }
        store.stop()
    }

    @Test func failedStartShowsTheFailure() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setStartFails(true)
        let store = makeStore(updater)
        store.start()
        await Eventually.wait { store.installed != nil }

        store.updateNow()
        await Eventually.wait { store.state == .failed(message: "Could not start the update") }
        store.stop()
    }

    @Test func tryAgainAfterAFailureStartsAgain() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.failed, commit: nil, message: "The build failed. See the log"))
        let store = makeStore(updater)
        store.start()
        await Eventually.wait { store.state == .failed(message: "The build failed. See the log") }

        store.updateNow()
        await Eventually.wait { updater.startCount == 1 }
        try? await Task.sleep(for: .milliseconds(20))
        store.stop()

        #expect(store.state.isRunning)
        #expect(updater.status() == nil)
    }

    @Test func loadsTheLog() async {
        let updater = FakeAppUpdater(installed: UpdateFixtures.installed)
        updater.setLog("line 1\nline 2\n")
        let store = makeStore(updater)

        store.loadLog()
        await Eventually.wait { store.log == "line 1\nline 2\n" }
    }
}

// MARK: - Private

private extension UpdateStoreTests {

    func makeStore(_ updater: FakeAppUpdater) -> UpdateStore {
        makeStore(updater, upToDateDuration: .seconds(10))
    }

    func makeStore(_ updater: FakeAppUpdater, upToDateDuration: Duration) -> UpdateStore {
        let clock = clock
        return UpdateStore(
            updater: updater,
            checkInterval: .milliseconds(5),
            statusInterval: .milliseconds(5),
            upToDateDuration: upToDateDuration,
            clock: { clock.now }
        )
    }
}
