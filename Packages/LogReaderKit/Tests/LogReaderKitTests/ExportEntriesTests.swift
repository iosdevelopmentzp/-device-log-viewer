import Foundation
import Testing
@testable import LogReaderKit

@MainActor
struct ExportEntriesTests {

    private struct WriteError: Error {}

    private let dialogs = FakeFileDialogs()
    private let writer = FakeFileWriter()
    private let revealer = FakeFileRevealer()
    private let destination = URL(fileURLWithPath: "/tmp/out/export.txt")

    private var export: ExportEntries {
        ExportEntries(dialogs: dialogs, writer: writer, revealer: revealer)
    }

    @Test func cancelWritesNothing() async {
        let harness = await startedHarness()

        let result = await export.export(harness.session, format: .log)

        #expect(result == false)
        #expect(dialogs.suggestedNames == ["log-2026.10.07-22-18-54-filtered.txt"])
        #expect(writer.writes.isEmpty)
        #expect(revealer.revealedURLs.isEmpty)
    }

    @Test func successWritesTheVisibleEntriesAndReveals() async {
        let harness = await startedHarness()
        harness.session.setSearchText("payment")
        await harness.waitForFilter()
        dialogs.saveLocation = destination

        let result = await export.export(harness.session, format: .log)

        #expect(result)
        #expect(writer.writes.map(\.url) == [destination])
        #expect(
            writer.writes.first?.data
                == ExportEntriesEncoder.logData(content: harness.session.content, recordIndices: [1])
        )
        #expect(revealer.revealedURLs == [destination])
        #expect(dialogs.presentedErrors.isEmpty)
    }

    @Test func writerErrorIsPresented() async {
        let harness = await startedHarness()
        dialogs.saveLocation = destination
        writer.fail(with: WriteError())

        let result = await export.export(harness.session, format: .json)

        #expect(result == false)
        #expect(dialogs.presentedErrors.count == 1)
        #expect(revealer.revealedURLs.isEmpty)
    }

    private func startedHarness() async -> SessionHarness {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        return harness
    }
}
