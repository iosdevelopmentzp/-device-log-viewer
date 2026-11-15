import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct LogCleanupPolicyTests {

    private let logsURL = URL(fileURLWithPath: "/tmp/device/app/Logs", isDirectory: true)

    @Test func olderFilesKeepTheNewestByCreationDate() {
        let app = app(files: [("b.txt", 20), ("c.txt", 30), ("a.txt", 10)])

        #expect(LogCleanupPolicy.olderFiles(of: app).map(\.lastPathComponent) == ["b.txt", "a.txt"])
    }

    @Test func olderFilesOfAnAppWithOneOrNoFilesAreEmpty() {
        #expect(LogCleanupPolicy.olderFiles(of: app(files: [("a.txt", 10)])).isEmpty)
        #expect(LogCleanupPolicy.olderFiles(of: app(files: [])).isEmpty)
    }

    @Test func allFilesOfAnApp() {
        let app = app(files: [("b.txt", 20), ("a.txt", 10)])

        #expect(LogCleanupPolicy.allFiles(of: app).map(\.lastPathComponent) == ["b.txt", "a.txt"])
    }

    @Test func allFilesOfADeviceCoverEveryApp() {
        let device = LogFixtures.device("A", apps: [
            LogFixtures.app("com.example.a", logsPath: "/tmp/a/Logs", files: ["1.txt", "2.txt"]),
            LogFixtures.app("com.example.b", logsPath: "/tmp/b/Logs", files: ["3.txt"])
        ])

        #expect(LogCleanupPolicy.allFiles(of: device).map(\.path) == ["/tmp/a/Logs/1.txt", "/tmp/a/Logs/2.txt", "/tmp/b/Logs/3.txt"])
    }
}

// MARK: - Private

private extension LogCleanupPolicyTests {

    func app(files: [(name: String, seconds: TimeInterval)]) -> AppLogContainer {
        AppLogContainer(
            bundleID: "com.example.app",
            logsURL: logsURL,
            files: files.map { file in
                LogFileItem(url: logsURL.appendingPathComponent(file.name), size: 1, createdAt: Date(timeIntervalSince1970: file.seconds))
            }
        )
    }
}
