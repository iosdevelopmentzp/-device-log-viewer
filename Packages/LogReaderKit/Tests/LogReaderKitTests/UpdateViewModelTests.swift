import Foundation
import Testing
@testable import LogReaderKit

@MainActor
struct UpdateViewModelTests {

    private let clock = ManualClock(now: UpdateFixtures.startedAt.addingTimeInterval(80))

    @Test func hiddenWhenThereIsNothingToShow() {
        let (model, _, _) = makeModel(installed: nil)

        #expect(model.item == nil)
        #expect(model.canCheck == false)
    }

    @Test func availableShowsTheCountAndTheCommits() async {
        let (model, updater, store) = makeModel(installed: UpdateFixtures.installed)
        updater.setCommits(UpdateFixtures.commits)

        store.start()
        await Eventually.wait { model.item?.kind == .available }
        store.stop()

        #expect(model.item?.title == "Update available · 2")
        #expect(model.item?.symbolName == "arrow.down.circle")
        #expect(model.item?.opensDetails == true)
        #expect(model.commits == UpdateFixtures.commits)
        #expect(model.commitsTitle == "2 new commits in main")
        #expect(model.canCheck)
    }

    @Test func runningShowsThePhaseAndTheElapsedTime() async {
        let (model, updater, store) = makeModel(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.building, commit: nil, message: nil))
        updater.setRunning(true)

        store.start()
        await Eventually.wait { model.item?.kind == .running }

        #expect(model.item?.title == "Building · 1:20")
        #expect(model.item?.symbolName == nil)
        #expect(model.item?.opensDetails == false)
        #expect(model.canCheck == false)

        updater.setStatus(UpdateFixtures.status(.fetching, commit: nil, message: nil))
        clock.advance(by: 45)
        await Eventually.wait { model.item?.title == "Getting changes · 2:05" }
        store.stop()
    }

    @Test func failedShowsTheMessageAndTheEndOfTheLog() async {
        let (model, updater, store) = makeModel(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.failed, commit: nil, message: "The build failed. See the log"))
        updater.setLog((1...250).map { "line \($0)" }.joined(separator: "\n") + "\n")

        store.start()
        await Eventually.wait { model.item?.kind == .failed }
        model.openDetails()
        await Eventually.wait { model.logText.isEmpty == false }
        store.stop()

        #expect(model.item?.title == "Update failed")
        #expect(model.item?.opensDetails == true)
        #expect(model.failureMessage == "The build failed. See the log")
        #expect(model.logText.hasPrefix("line 51\n"))
        #expect(model.logText.hasSuffix("line 250"))
    }

    @Test func updatedCanBeDismissed() async {
        let (model, updater, store) = makeModel(installed: UpdateFixtures.installed)
        updater.setStatus(UpdateFixtures.status(.done, commit: UpdateFixtures.installedCommit, message: nil))

        store.start()
        await Eventually.wait { model.item?.kind == .updated }

        #expect(model.item?.title == "Updated to 4bf0b5d")
        #expect(model.item?.canDismiss == true)

        model.dismissUpdated()
        store.stop()

        #expect(model.item == nil)
    }

    @Test func checkNowShowsUpToDate() async {
        let (model, _, store) = makeModel(installed: UpdateFixtures.installed)
        store.start()
        await Eventually.wait { model.canCheck }

        model.checkNow()
        await Eventually.wait { model.item?.kind == .upToDate }
        store.stop()

        #expect(model.item?.title == "Up to date")
    }

    @Test func updateNowAndTryAgainStartTheUpdate() async {
        let (model, updater, store) = makeModel(installed: UpdateFixtures.installed)
        updater.setCommits(UpdateFixtures.commits)
        updater.setStartFails(true)
        store.start()
        await Eventually.wait { model.item?.kind == .available }

        model.updateNow()
        await Eventually.wait { model.item?.kind == .failed }

        updater.setStartFails(false)
        model.tryAgain()
        await Eventually.wait { updater.startCount == 2 }
        store.stop()

        #expect(model.item?.kind == .running)
    }

    @Test func settingsTextsWithoutAnInstalledBuild() {
        let (model, _, _) = makeModel(installed: nil)

        #expect(model.installedText == "Not installed with Scripts/install.sh")
        #expect(model.statusText == "This build does not update itself")
        #expect(model.canUpdate == false)
    }

    @Test func settingsTextsFollowTheChecks() async {
        let (model, updater, store) = makeModel(installed: UpdateFixtures.installed)

        store.start()
        await Eventually.wait { model.statusText.hasPrefix("Up to date") }

        #expect(model.installedText == "4bf0b5d, \(ShortDateTimeText.text(for: UpdateFixtures.startedAt))")
        #expect(model.statusText == "Up to date · checked \(ShortDateTimeText.text(for: clock.now))")
        #expect(model.canUpdate)

        updater.setCommits(UpdateFixtures.commits)
        model.checkNow()
        await Eventually.wait { model.statusText == "2 new commits in main" }
        store.stop()
    }

    @Test func updateNowStartsWithoutNewCommits() async {
        let (model, updater, store) = makeModel(installed: UpdateFixtures.installed)
        store.start()
        await Eventually.wait { model.statusText.hasPrefix("Up to date") }

        model.updateNow()
        await Eventually.wait { updater.startCount == 1 }
        store.stop()

        #expect(model.statusText == "Getting changes · 0:00")
        #expect(model.canUpdate == false)
        #expect(model.canCheck == false)
    }

    @Test func singleCommitTitle() async {
        let (model, updater, store) = makeModel(installed: UpdateFixtures.installed)
        updater.setCommits([UpdateFixtures.commits[0]])

        store.start()
        await Eventually.wait { model.item?.kind == .available }
        store.stop()

        #expect(model.commitsTitle == "1 new commit in main")
    }
}

// MARK: - Private

private extension UpdateViewModelTests {

    func makeModel(installed: InstalledBuild?) -> (UpdateViewModel, FakeAppUpdater, UpdateStore) {
        let updater = FakeAppUpdater(installed: installed)
        let clock = clock
        let store = UpdateStore(
            updater: updater,
            checkInterval: .seconds(10),
            statusInterval: .milliseconds(5),
            upToDateDuration: .seconds(10),
            clock: { clock.now }
        )
        return (UpdateViewModel(store: store), updater, store)
    }
}
