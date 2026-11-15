import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct ErrorAlertControllerTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let attention = FakeAppAttention()

    @Test func noAlertWhileTheAppIsActive() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let controller = makeController(attachedTo: harness)
        attention.isAppActive = true

        await harness.start(with: [Self.debug])
        await harness.send([Self.error])

        #expect(attention.attentionRequests == 0)
        #expect(attention.badges.isEmpty)
        #expect(controller.pendingErrorCount == 0)
        controller.stop()
    }

    @Test func theFirstLoadOfAFileIsNotAnAlert() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let controller = makeController(attachedTo: harness)
        attention.isAppActive = false

        await harness.start(with: [Self.error, Self.fault])

        #expect(attention.attentionRequests == 0)
        #expect(controller.pendingErrorCount == 0)
        controller.stop()
    }

    @Test func noAlertWhenTheSettingIsOff() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let controller = makeController(attachedTo: harness)
        settings.alertsOnErrors = false

        await harness.start(with: [Self.debug])
        await harness.send([Self.error])

        #expect(attention.attentionRequests == 0)
        #expect(attention.badges.isEmpty)
        controller.stop()
    }

    @Test func errorsWhileInactiveRequestAttentionOnceAndCountInTheBadge() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let controller = makeController(attachedTo: harness)

        await harness.start(with: [Self.debug])
        await harness.send([Self.error])

        #expect(attention.attentionRequests == 1)
        #expect(attention.badges == ["1"])

        await harness.send([Self.fault, Self.debug, Self.error])

        #expect(attention.attentionRequests == 1)
        #expect(attention.badges == ["1", "3"])
        #expect(controller.pendingErrorCount == 3)
        controller.stop()
    }

    @Test func activationClearsTheBadgeAndTheNextErrorAlertsAgain() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let controller = makeController(attachedTo: harness)
        await harness.start(with: [Self.debug])
        await harness.send([Self.error])

        attention.simulateActivation()

        #expect(attention.badges == ["1", nil])
        #expect(controller.pendingErrorCount == 0)

        attention.isAppActive = false
        await harness.send([Self.error])

        #expect(attention.attentionRequests == 2)
        #expect(attention.badges == ["1", nil, "1"])
        controller.stop()
    }

    @Test func debugOnlyBatchChangesNothing() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let controller = makeController(attachedTo: harness)

        await harness.start(with: [Self.debug, Self.info])

        #expect(attention.attentionRequests == 0)
        #expect(attention.badges.isEmpty)
        #expect(controller.pendingErrorCount == 0)
        controller.stop()
    }

    @Test func attachingToANewSessionStopsCountingTheOldOne() async {
        var first = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        var second = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let controller = makeController(attachedTo: first)
        await first.start(with: [Self.debug])

        controller.attach(to: second.session)
        await first.send([Self.error])

        #expect(first.session.appendObserver == nil)
        #expect(attention.attentionRequests == 0)

        await second.start(with: [Self.debug])
        await second.send([Self.error])

        #expect(attention.attentionRequests == 1)
        #expect(attention.badges == ["1"])
        controller.stop()
    }

    @Test func alertLevelsComeFromTheProfile() async {
        var profile = LogFixtures.profile
        profile.levels = profile.levels.map { level in
            var level = level
            level.alerts = level.id == "warning"
            return level
        }
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1), profile: profile)
        let controller = makeController(attachedTo: harness)
        await harness.start(with: [Self.debug])

        await harness.send([Self.error, Self.fault, LogFixtures.entry("Slow", level: "WRN")])

        #expect(controller.pendingErrorCount == 1)
        #expect(attention.badges == ["1"])
        controller.stop()
    }

    @Test func stopClearsTheBadgeAndTheObservers() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let controller = makeController(attachedTo: harness)
        await harness.start(with: [Self.debug])
        await harness.send([Self.error])

        controller.stop()

        #expect(attention.badges == ["1", nil])
        #expect(attention.observer == nil)
        #expect(harness.session.appendObserver == nil)
    }
}

// MARK: - Private

private extension ErrorAlertControllerTests {

    static let error = LogFixtures.entry("Payment failed", level: "ERR")
    static let fault = LogFixtures.entry("Crash", level: "FLT")
    static let debug = LogFixtures.entry("Noise", level: "DBG")
    static let info = LogFixtures.entry("Hello", level: "INF")

    func makeController(attachedTo harness: SessionHarness) -> ErrorAlertController {
        let controller = ErrorAlertController(settings: settings, attention: attention)
        controller.start()
        controller.attach(to: harness.session)
        return controller
    }
}
