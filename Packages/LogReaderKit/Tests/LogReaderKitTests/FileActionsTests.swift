import Foundation
import Testing
@testable import LogReaderKit

@MainActor
struct FileActionsTests {

    private struct CopyError: Error {}

    private let pasteboard = FakePasteboard()
    private let revealer = FakeFileRevealer()
    private let dialogs = FakeFileDialogs()
    private let copier = FakeFileCopier()
    private let url = URL(fileURLWithPath: "/tmp/logs/log-2026.10.07-22:18:54.txt")

    private var actions: FileActions {
        FileActions(pasteboard: pasteboard, revealer: revealer, dialogs: dialogs, copier: copier)
    }

    @Test func revealAndOpenForwardToTheRevealer() {
        actions.reveal(url)
        actions.openInDefaultApp(url)
        actions.openFolder(url.deletingLastPathComponent())

        #expect(revealer.revealedURLs == [url])
        #expect(revealer.openedURLs == [url, url.deletingLastPathComponent()])
    }

    @Test func copyActionsWriteToThePasteboard() {
        actions.copyPath(url)
        actions.copyFileName(url)
        actions.copyText("com.example")
        actions.copyFile(url)

        #expect(pasteboard.writtenTexts == [url.path, "log-2026.10.07-22:18:54.txt", "com.example"])
        #expect(pasteboard.writtenFileURLs == [url])
    }

    @Test func saveCopyCopiesWithReplaceAndReveals() {
        let destination = URL(fileURLWithPath: "/tmp/out/copy.txt")
        dialogs.saveLocation = destination

        actions.saveCopy(of: url)

        #expect(dialogs.suggestedNames == ["log-2026.10.07-22-18-54.txt"])
        #expect(copier.copies == [FakeFileCopier.Copy(source: url, destination: destination, replacing: true)])
        #expect(revealer.revealedURLs == [destination])
    }

    @Test func saveCopyDoesNothingWhenCancelled() {
        actions.saveCopy(of: url)

        #expect(copier.copies.isEmpty)
        #expect(revealer.revealedURLs.isEmpty)
    }

    @Test func saveCopyPresentsErrors() {
        dialogs.saveLocation = URL(fileURLWithPath: "/tmp/out/copy.txt")
        copier.errorToThrow = CopyError()

        actions.saveCopy(of: url)

        #expect(dialogs.presentedErrors.count == 1)
        #expect(revealer.revealedURLs.isEmpty)
    }
}
