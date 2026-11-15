import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct DeleteLogFilesTests {

    private struct TrashError: Error {}

    private let trasher = FakeFileTrasher()
    private let dialogs = FakeFileDialogs()
    private let app = LogFixtures.app("com.example.chat", logsPath: "/tmp/a/Logs", files: ["3.txt", "2.txt", "1.txt"])

    private var deleteLogFiles: DeleteLogFiles {
        DeleteLogFiles(trasher: trasher, dialogs: dialogs)
    }

    @Test func trashMovesOneFileWithoutConfirmation() {
        let url = URL(fileURLWithPath: "/tmp/a/Logs/1.txt")

        let trashed = deleteLogFiles.trash(url)

        #expect(trashed == [url])
        #expect(trasher.trashedURLs == [url])
        #expect(dialogs.confirmations.isEmpty)
    }

    @Test func trashPresentsAnError() {
        trasher.errorToThrow = TrashError()

        let trashed = deleteLogFiles.trash(URL(fileURLWithPath: "/tmp/a/Logs/1.txt"))

        #expect(trashed.isEmpty)
        #expect(dialogs.presentedErrors.count == 1)
    }

    @Test func deleteOlderFilesAsksAndTrashesWhenConfirmed() {
        dialogs.confirmAnswer = true

        let trashed = deleteLogFiles.deleteOlderFiles(of: app)

        #expect(trashed.map(\.lastPathComponent) == ["2.txt", "1.txt"])
        #expect(trasher.trashedURLs == trashed)
        #expect(dialogs.confirmations.map(\.title) == ["Move 2 older log files of com.example.chat to Trash?"])
        #expect(dialogs.confirmations.map(\.confirmTitle) == ["Move to Trash"])
    }

    @Test func deleteAllFilesDoesNothingWhenCancelled() {
        dialogs.confirmAnswer = false

        let trashed = deleteLogFiles.deleteAllFiles(of: app)

        #expect(trashed.isEmpty)
        #expect(trasher.trashedURLs.isEmpty)
        #expect(dialogs.confirmations.map(\.title) == ["Move 3 log files of com.example.chat to Trash?"])
    }

    @Test func deleteAllFilesOfADeviceNamesTheSimulator() {
        dialogs.confirmAnswer = true
        let device = LogFixtures.device("A", apps: [
            app,
            LogFixtures.app("com.example.b", logsPath: "/tmp/b/Logs", files: ["4.txt"])
        ])

        let trashed = deleteLogFiles.deleteAllFiles(of: device)

        #expect(trashed.count == 4)
        #expect(dialogs.confirmations.map(\.title) == ["Move 4 log files of iPhone A to Trash?"])
    }

    @Test func deleteAllFilesOfAPhysicalDeviceDoesNothing() {
        dialogs.confirmAnswer = true
        let device = SimulatorDevice(
            udid: "PHONE-1",
            name: "Test Phone",
            runtime: "iOS 27.0",
            isBooted: true,
            folderURL: URL(fileURLWithPath: "/tmp/cache/PHONE-1", isDirectory: true),
            apps: [app],
            kind: .physical(.usb)
        )

        let trashed = deleteLogFiles.deleteAllFiles(of: device)

        #expect(trashed.isEmpty)
        #expect(trasher.trashedURLs.isEmpty)
        #expect(dialogs.confirmations.isEmpty)
    }

    @Test func oneFileUsesTheSingularNoun() {
        dialogs.confirmAnswer = true
        let single = LogFixtures.app("com.example.chat", logsPath: "/tmp/a/Logs", files: ["1.txt"])

        _ = deleteLogFiles.deleteAllFiles(of: single)

        #expect(dialogs.confirmations.map(\.title) == ["Move 1 log file of com.example.chat to Trash?"])
    }

    @Test func nothingToDeleteAsksNothing() {
        let single = LogFixtures.app("com.example.chat", logsPath: "/tmp/a/Logs", files: ["1.txt"])

        let trashed = deleteLogFiles.deleteOlderFiles(of: single)

        #expect(trashed.isEmpty)
        #expect(dialogs.confirmations.isEmpty)
    }

    @Test func anErrorInTheMiddleStopsAndReturnsWhatWasTrashed() {
        dialogs.confirmAnswer = true
        trasher.errorToThrow = TrashError()
        trasher.failingURL = URL(fileURLWithPath: "/tmp/a/Logs/2.txt")

        let trashed = deleteLogFiles.deleteAllFiles(of: app)

        #expect(trashed.map(\.lastPathComponent) == ["3.txt"])
        #expect(trasher.trashedURLs == trashed)
        #expect(dialogs.presentedErrors.count == 1)
    }
}
