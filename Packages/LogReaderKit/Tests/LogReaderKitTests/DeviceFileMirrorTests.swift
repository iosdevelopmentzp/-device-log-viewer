import Foundation
import Testing
@testable import LogReaderKit

struct DeviceFileMirrorTests {

    private let runner = FakeDevicectlRunner()
    private let fileName = "log-2026.11.07-10:34:52.txt"
    private let cacheURL: URL
    private let mirror: DeviceFileMirror

    init() {
        cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeviceFileMirrorTests-\(UUID().uuidString)/PHONE-1/com.example.chat", isDirectory: true)
            .appendingPathComponent(fileName)
        mirror = DeviceFileMirror(
            location: DeviceFileLocation(udid: "PHONE-1", bundleID: "com.example.chat", fileName: fileName),
            logsPath: "Library/Application Support/Logs",
            cacheURL: cacheURL,
            runner: runner,
            interval: .milliseconds(10),
            isEnabled: { true }
        )
    }

    @Test func firstCopyCreatesTheCacheFile() throws {
        defer { removeCache() }
        runner.setRemoteFile(fileName, content: "AAA")

        mirror.mirrorOnce()

        #expect(try cachedText() == "AAA")
        #expect(try partFiles().isEmpty)
    }

    @Test func growingFileAppendsOnlyTheNewBytes() throws {
        defer { removeCache() }
        runner.setRemoteFile(fileName, content: "AAA")
        mirror.mirrorOnce()
        let inode = try fileNumber()

        runner.setRemoteFile(fileName, content: "AAABBB")
        mirror.mirrorOnce()

        #expect(try cachedText() == "AAABBB")
        #expect(try fileNumber() == inode)
    }

    @Test func unchangedSizeSkipsTheCopy() {
        defer { removeCache() }
        runner.setRemoteFile(fileName, content: "AAA")

        mirror.mirrorOnce()
        mirror.mirrorOnce()

        #expect(runner.callCount(DevicectlFixtures.filesCommand) == 2)
        #expect(runner.callCount(DevicectlFixtures.copyCommand) == 1)
    }

    @Test func smallerFileReplacesTheCache() throws {
        defer { removeCache() }
        runner.setRemoteFile(fileName, content: "AAABBB")
        mirror.mirrorOnce()
        let inode = try fileNumber()

        runner.setRemoteFile(fileName, content: "C")
        mirror.mirrorOnce()

        #expect(try cachedText() == "C")
        #expect(try fileNumber() != inode)
    }

    @Test func goneFileKeepsTheCacheAndANewFileReplacesIt() throws {
        defer { removeCache() }
        runner.setRemoteFile(fileName, content: "AAA")
        mirror.mirrorOnce()

        runner.setRemoteFile(fileName, content: nil)
        mirror.mirrorOnce()
        #expect(try cachedText() == "AAA")

        runner.setRemoteFile(fileName, content: "ZZZZZZ")
        mirror.mirrorOnce()
        #expect(try cachedText() == "ZZZZZZ")
    }

    @Test func failedCopyKeepsTheCacheAndRetries() throws {
        defer { removeCache() }
        runner.setRemoteFile(fileName, content: "AAA")
        mirror.mirrorOnce()

        runner.setRemoteFile(fileName, content: "AAABBB")
        runner.setFailing(DevicectlFixtures.copyCommand, true)
        mirror.mirrorOnce()
        #expect(try cachedText() == "AAA")

        runner.setFailing(DevicectlFixtures.copyCommand, false)
        mirror.mirrorOnce()
        #expect(try cachedText() == "AAABBB")
        #expect(try partFiles().isEmpty)
    }

    @Test func disabledMirrorRunsNothing() {
        defer { removeCache() }
        let disabled = DeviceFileMirror(
            location: DeviceFileLocation(udid: "PHONE-1", bundleID: "com.example.chat", fileName: fileName),
            logsPath: "Library/Application Support/Logs",
            cacheURL: cacheURL,
            runner: runner,
            interval: .milliseconds(10),
            isEnabled: { false }
        )

        disabled.mirrorOnce()

        #expect(runner.calls.isEmpty)
    }

    @Test func startCallsBackAfterTheFirstCopyAndStopEndsTheTicks() async throws {
        defer { removeCache() }
        runner.setRemoteFile(fileName, content: "AAA")

        await withCheckedContinuation { continuation in
            mirror.start { continuation.resume() }
        }
        #expect(try cachedText() == "AAA")

        mirror.stop()
        try await Task.sleep(for: .milliseconds(50))
        let count = runner.calls.count
        try await Task.sleep(for: .milliseconds(50))
        #expect(runner.calls.count == count)
    }

    private func cachedText() throws -> String {
        try String(contentsOf: cacheURL, encoding: .utf8)
    }

    private func fileNumber() throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: cacheURL.path)
        return try #require(attributes[.systemFileNumber] as? Int)
    }

    private func partFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: cacheURL.deletingLastPathComponent().path)
            .filter { $0.hasSuffix(".part") }
    }

    private func removeCache() {
        try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
    }
}
