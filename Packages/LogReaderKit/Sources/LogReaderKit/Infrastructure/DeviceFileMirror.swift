import Foundation
import LogReaderCore

final class DeviceFileMirror: @unchecked Sendable {

    private let location: DeviceFileLocation
    private let logsPath: String
    private let cacheURL: URL
    private let partURL: URL
    private let runner: any DevicectlCommandRunning
    private let interval: DispatchTimeInterval
    private let isEnabled: @Sendable () -> Bool
    private let queue: DispatchQueue
    private var copiedSize: Int64?
    private var isRemoteMissing = false
    private var isRunning = false
    private var isStopped = false
    private var onFirstAttempt: (@Sendable () -> Void)?

    private static let mergeLock = NSLock()

    init(
        location: DeviceFileLocation,
        logsPath: String,
        cacheURL: URL,
        runner: any DevicectlCommandRunning,
        interval: DispatchTimeInterval,
        isEnabled: @escaping @Sendable () -> Bool
    ) {
        self.location = location
        self.logsPath = logsPath
        self.cacheURL = cacheURL
        self.partURL = cacheURL.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).part")
        self.runner = runner
        self.interval = interval
        self.isEnabled = isEnabled
        self.queue = DispatchQueue(label: "DeviceFileMirror.\(cacheURL.lastPathComponent)", qos: .utility)
    }

    func start(onFirstAttempt: @escaping @Sendable () -> Void) {
        queue.async { [weak self] in
            guard let self else { return onFirstAttempt() }
            guard isStopped == false, isRunning == false else { return onFirstAttempt() }
            isRunning = true
            self.onFirstAttempt = onFirstAttempt
            tick()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            isStopped = true
            isRunning = false
            finishFirstAttempt()
        }
    }

    func mirrorOnce() {
        guard isEnabled() else { return }
        defer { try? FileManager.default.removeItem(at: partURL) }
        do {
            let list = try runner.decode(
                DevicectlFileList.self,
                arguments: DevicectlCommand.files(device: location.udid, bundleID: location.bundleID, logsPath: logsPath)
            )
            let remotePath = DevicectlFileList.lastFolder(of: logsPath) + "/" + location.fileName
            guard let remote = list.files.first(where: { $0.isDirectory == false && $0.relativePath == remotePath }) else {
                isRemoteMissing = true
                return
            }
            guard isRemoteMissing || remote.size != copiedSize else { return }
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: partURL)
            _ = try runner.run(DevicectlCommand.copy(
                device: location.udid,
                bundleID: location.bundleID,
                logsPath: logsPath,
                fileName: location.fileName,
                destination: partURL
            ))
            copiedSize = try Self.mergeLock.withLock { try merge(replacing: isRemoteMissing) }
            isRemoteMissing = false
        } catch {
            return
        }
    }
}

// MARK: - Private

private extension DeviceFileMirror {

    func tick() {
        guard isRunning else { return }
        mirrorOnce()
        finishFirstAttempt()
        queue.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self else { return }
            tick()
        }
    }

    func finishFirstAttempt() {
        let callback = onFirstAttempt
        onFirstAttempt = nil
        callback?()
    }

    func merge(replacing: Bool) throws -> Int64 {
        let newSize = try Self.size(of: partURL)
        guard replacing == false, let cachedSize = try? Self.size(of: cacheURL), newSize >= cachedSize else {
            try replaceCache()
            return newSize
        }
        guard newSize > cachedSize else { return newSize }
        try appendPart(from: cachedSize)
        return newSize
    }

    func appendPart(from offset: Int64) throws {
        let input = try FileHandle(forReadingFrom: partURL)
        defer { try? input.close() }
        try input.seek(toOffset: UInt64(offset))
        guard let data = try input.readToEnd(), data.isEmpty == false else { return }
        let output = try FileHandle(forWritingTo: cacheURL)
        defer { try? output.close() }
        try output.seekToEnd()
        try output.write(contentsOf: data)
    }

    func replaceCache() throws {
        guard rename(partURL.path, cacheURL.path) == 0 else { throw DevicectlError.cacheNotReplaced(errno: errno) }
    }

    static func size(of url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
