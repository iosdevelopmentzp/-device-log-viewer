import Foundation
import Testing
@testable import LogReaderKit

struct GitAppUpdaterTests {

    private let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("GitAppUpdaterTests-\(UUID().uuidString)", isDirectory: true)
    private let appURL = URL(fileURLWithPath: "/tmp/GitAppUpdaterTests/LogReader.app")

    @Test func listsTheCommitsThatTheInstalledBuildDoesNotHave() throws {
        defer { removeRoot() }
        let repository = try makeRepository()
        let updater = try makeUpdater(installedCommit: repository.installed)

        let installed = try #require(updater.installed())
        let commits = try updater.check(installed: installed)

        #expect(commits.map(\.subject) == ["Fourth", "Third"])
        #expect(commits.allSatisfy { $0.shortHash.count >= 7 })
    }

    @Test func installedBuildEqualToMainHasNoUpdate() throws {
        defer { removeRoot() }
        let repository = try makeRepository()
        let updater = try makeUpdater(installedCommit: repository.mainHead)

        let installed = try #require(updater.installed())

        #expect(try updater.check(installed: installed).isEmpty)
    }

    @Test func installedBuildNotInMainHasNoUpdate() throws {
        defer { removeRoot() }
        let repository = try makeRepository()
        let updater = try makeUpdater(installedCommit: repository.featureHead)

        let installed = try #require(updater.installed())

        #expect(try updater.check(installed: installed).isEmpty)
    }

    @Test func missingSourceFailsTheCheck() throws {
        defer { removeRoot() }
        let updater = try makeUpdater(installedCommit: "4bf0b5d")
        let installed = try #require(updater.installed())

        #expect(throws: (any Error).self) { try updater.check(installed: installed) }
    }

    @Test func appOutsideTheInstallPathIsNotInstalled() throws {
        defer { removeRoot() }
        try writeInstalled(commit: "4bf0b5d")
        let updater = GitAppUpdater(
            directory: root,
            runningAppURL: URL(fileURLWithPath: "/tmp/DerivedData/LogReader.app"),
            installedAppURL: appURL,
            timeout: .seconds(30)
        )

        #expect(updater.installed() == nil)
    }

    @Test func missingInstalledFileMeansNotInstalled() {
        let updater = GitAppUpdater(directory: root, runningAppURL: appURL, installedAppURL: appURL, timeout: .seconds(30))

        #expect(updater.installed() == nil)
        #expect(updater.status() == nil)
        #expect(updater.log() == "")
        #expect(updater.isUpdateRunning() == false)
    }

    @Test func readsAndClearsTheStatus() throws {
        defer { removeRoot() }
        let updater = try makeUpdater(installedCommit: "4bf0b5d")
        let json = #"{"phase": "installing", "startedAt": "2026-11-07T10:15:00Z", "commit": null, "message": null}"#
        try Data(json.utf8).write(to: updateDirectory.appendingPathComponent("status.json"))

        #expect(updater.status()?.phase == .installing)

        updater.clearStatus()

        #expect(updater.status() == nil)
    }

    @Test func liveLockMeansARunningUpdate() throws {
        defer { removeRoot() }
        let updater = try makeUpdater(installedCommit: "4bf0b5d")
        let lock = updateDirectory.appendingPathComponent("update.lock")

        try Data("\(getpid())\n".utf8).write(to: lock)
        #expect(updater.isUpdateRunning())

        try Data("\(try finishedProcessID())\n".utf8).write(to: lock)
        #expect(updater.isUpdateRunning() == false)

        try Data("not a pid".utf8).write(to: lock)
        #expect(updater.isUpdateRunning() == false)
    }

    @Test func startRunsTheScriptDetachedWithItsOutputInTheLog() async throws {
        defer { removeRoot() }
        let source = root.appendingPathComponent("source", isDirectory: true)
        let scripts = source.appendingPathComponent("Scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        let script = scripts.appendingPathComponent("update.sh")
        try Data("#!/bin/zsh\necho \"started in $PWD\"\necho problem >&2\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let updater = try makeUpdater(installedCommit: "4bf0b5d", source: source.path)

        try updater.start()

        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while updater.log().contains("problem") == false, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(updater.log().contains("started in "))
        #expect(updater.log().contains("problem"))
    }
}

// MARK: - Private

private extension GitAppUpdaterTests {

    struct Repository {
        let installed: String
        let mainHead: String
        let featureHead: String
    }

    var updateDirectory: URL { root.appendingPathComponent("update", isDirectory: true) }
    var sourcePath: String { root.appendingPathComponent("source").path }

    func makeRepository() throws -> Repository {
        let work = root.appendingPathComponent("work").path
        try FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
        try git(["init", "--quiet", "--initial-branch", "main", work])
        try commit("First", in: work)
        try commit("Second", in: work)
        let installed = try git(["-C", work, "rev-parse", "HEAD"])
        try git(["clone", "--quiet", "--branch", "main", work, sourcePath])
        try commit("Third", in: work)
        try commit("Fourth", in: work)
        let mainHead = try git(["-C", work, "rev-parse", "HEAD"])
        try git(["-C", work, "switch", "--quiet", "--create", "feature"])
        try commit("Feature", in: work)
        let featureHead = try git(["-C", work, "rev-parse", "HEAD"])
        try git(["-C", work, "switch", "--quiet", "main"])
        return Repository(installed: installed, mainHead: mainHead, featureHead: featureHead)
    }

    func commit(_ subject: String, in work: String) throws {
        try git(["-C", work, "commit", "--quiet", "--allow-empty", "--message", subject])
    }

    func makeUpdater(installedCommit: String) throws -> GitAppUpdater {
        try makeUpdater(installedCommit: installedCommit, source: sourcePath)
    }

    func makeUpdater(installedCommit: String, source: String) throws -> GitAppUpdater {
        try writeInstalled(commit: installedCommit, source: source)
        return GitAppUpdater(directory: root, runningAppURL: appURL, installedAppURL: appURL, timeout: .seconds(30))
    }

    func writeInstalled(commit: String) throws {
        try writeInstalled(commit: commit, source: sourcePath)
    }

    func writeInstalled(commit: String, source: String) throws {
        try FileManager.default.createDirectory(at: updateDirectory, withIntermediateDirectories: true)
        let json = """
        {"commit": "\(commit)", "branch": "main", "source": "\(source)", "installedAt": "2026-11-07T10:15:00Z"}
        """
        try Data(json.utf8).write(to: updateDirectory.appendingPathComponent("installed.json"))
    }

    func removeRoot() {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func git(_ arguments: [String]) throws -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-c", "user.name=Test",
            "-c", "user.email=test@example.com",
            "-c", "commit.gpgsign=false",
            "-c", "core.hooksPath=/dev/null"
        ] + arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0)
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func finishedProcessID() throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }
}
