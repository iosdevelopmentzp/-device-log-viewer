import Foundation

public final class GitAppUpdater: Sendable {

    private let directory: URL
    private let runningAppURL: URL
    private let installedAppURL: URL
    private let timeout: DispatchTimeInterval

    private static let gitPath = "/usr/bin/git"
    private static let zshPath = "/bin/zsh"
    private static let branch = "main"
    private static let remoteBranch = "origin/main"
    private static let startCommand = #"/usr/bin/nohup "$1" > "$2" 2>&1 < /dev/null &"#

    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LogReader", isDirectory: true)
    }

    public static var defaultInstalledAppURL: URL {
        URL(fileURLWithPath: "/Applications/LogReader.app", isDirectory: true)
    }

    public init(directory: URL, runningAppURL: URL, installedAppURL: URL, timeout: DispatchTimeInterval) {
        self.directory = directory
        self.runningAppURL = runningAppURL
        self.installedAppURL = installedAppURL
        self.timeout = timeout
    }
}

// MARK: - AppUpdater

extension GitAppUpdater: AppUpdater {

    public func installed() -> InstalledBuild? {
        guard Self.path(of: runningAppURL) == Self.path(of: installedAppURL) else { return nil }
        guard let data = try? Data(contentsOf: installedFileURL) else { return nil }
        return UpdateDecoder.installedBuild(from: data)
    }

    public func check(installed: InstalledBuild) throws -> [UpdateCommit] {
        let fetch = try git(installed.source, ["fetch", "--quiet", "origin", Self.branch])
        guard fetch.status == 0 else { throw GitAppUpdaterError.failed(status: fetch.status) }
        let ancestor = try git(installed.source, ["merge-base", "--is-ancestor", installed.commit, Self.remoteBranch])
        guard ancestor.status == 0 else { return [] }
        let log = try git(installed.source, ["log", "--format=%h%x1f%s", "\(installed.commit)..\(Self.remoteBranch)"])
        guard log.status == 0 else { throw GitAppUpdaterError.failed(status: log.status) }
        return UpdateDecoder.commits(fromGitLog: String(decoding: log.output, as: UTF8.self))
    }

    public func start() throws {
        guard let installed = installed() else { throw GitAppUpdaterError.notInstalled }
        let script = URL(fileURLWithPath: installed.source).appendingPathComponent("Scripts/update.sh")
        let result = try run(Self.zshPath, ["-c", Self.startCommand, "zsh", script.path, logFileURL.path])
        guard result.status == 0 else { throw GitAppUpdaterError.failed(status: result.status) }
    }

    public func status() -> UpdateStatus? {
        guard let data = try? Data(contentsOf: statusFileURL) else { return nil }
        return UpdateDecoder.status(from: data)
    }

    public func clearStatus() {
        try? FileManager.default.removeItem(at: statusFileURL)
    }

    public func log() -> String {
        guard let data = try? Data(contentsOf: logFileURL) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    public func isUpdateRunning() -> Bool {
        guard let data = try? Data(contentsOf: lockFileURL) else { return false }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = pid_t(text), pid > 0 else { return false }
        return kill(pid, 0) == 0
    }
}

// MARK: - Private

private extension GitAppUpdater {

    var updateDirectory: URL { directory.appendingPathComponent("update", isDirectory: true) }
    var installedFileURL: URL { updateDirectory.appendingPathComponent("installed.json") }
    var statusFileURL: URL { updateDirectory.appendingPathComponent("status.json") }
    var logFileURL: URL { updateDirectory.appendingPathComponent("update.log") }
    var lockFileURL: URL { updateDirectory.appendingPathComponent("update.lock") }

    static func path(of url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    func git(_ source: String, _ arguments: [String]) throws -> (status: Int32, output: Data) {
        try run(Self.gitPath, ["-C", source] + arguments)
    }

    func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: Data) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogReader-update-\(UUID().uuidString).txt")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let output = try FileHandle(forWritingTo: outputURL)
        defer { try? output.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()

        guard finished.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            throw GitAppUpdaterError.timedOut
        }
        return (process.terminationStatus, try Data(contentsOf: outputURL))
    }
}
