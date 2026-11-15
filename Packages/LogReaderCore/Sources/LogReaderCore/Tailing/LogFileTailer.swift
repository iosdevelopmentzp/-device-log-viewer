import Foundation

public final class LogFileTailer: @unchecked Sendable {

    struct FileIdentity: Equatable {
        let device: dev_t
        let inode: ino_t
    }

    public let url: URL

    private let profile: LogProfile
    private let queue: DispatchQueue
    private let readDelay: DispatchTimeInterval
    private let pollInterval: DispatchTimeInterval
    private var continuation: AsyncStream<LogSourceEvent>.Continuation?
    private var handle: FileHandle?
    private var identity: FileIdentity?
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?
    private var indexer: LogIndexer
    private var offset: UInt64 = 0
    private var hasEmitted = false
    private var isMissingReported = false
    private var isReadScheduled = false

    public init(url: URL, profile: LogProfile, readDelay: DispatchTimeInterval, pollInterval: DispatchTimeInterval) {
        self.url = url
        self.profile = profile
        self.indexer = LogIndexer(profile: profile)
        self.readDelay = readDelay
        self.pollInterval = pollInterval
        self.queue = DispatchQueue(label: "LogFileTailer.\(url.lastPathComponent)", qos: .userInitiated)
    }

    deinit {
        source?.cancel()
        timer?.cancel()
    }
}

// MARK: - LogSource

extension LogFileTailer: LogSource {

    public func events() -> AsyncStream<LogSourceEvent> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                stop()
            }
            queue.async { [weak self] in
                guard let self else { return }
                self.continuation = continuation
                readNewBytes()
                startTimer()
            }
        }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            timer?.cancel()
            timer = nil
            closeHandle()
            continuation?.finish()
            continuation = nil
        }
    }
}

// MARK: - Private

private extension LogFileTailer {

    func readNewBytes() {
        guard continuation != nil else { return }
        if handle != nil, pathIdentity() != identity {
            closeHandle()
        }
        if handle == nil {
            guard openHandle() else {
                reportMissing()
                return
            }
            restart()
        }
        guard let handle else { return }

        let size = (try? handle.seekToEnd()) ?? 0
        if size < offset {
            restart()
        }
        guard size > offset else { return }

        do {
            try handle.seek(toOffset: offset)
            guard let data = try handle.read(upToCount: Int(size - offset)), data.isEmpty == false else { return }
            offset += UInt64(data.count)
            guard let batch = indexer.consume(data) else { return }
            hasEmitted = true
            continuation?.yield(.batch(batch))
        } catch {
            closeHandle()
        }
    }

    func restart() {
        offset = 0
        indexer = LogIndexer(profile: profile)
        isMissingReported = false
        guard hasEmitted else { return }
        hasEmitted = false
        continuation?.yield(.reset)
    }

    func reportMissing() {
        guard isMissingReported == false else { return }
        isMissingReported = true
        continuation?.yield(.missing)
    }

    func openHandle() -> Bool {
        guard let newHandle = try? FileHandle(forReadingFrom: url) else { return false }
        handle = newHandle
        identity = descriptorIdentity(newHandle.fileDescriptor)
        installSource(fileDescriptor: newHandle.fileDescriptor)
        return true
    }

    func closeHandle() {
        source?.cancel()
        source = nil
        try? handle?.close()
        handle = nil
        identity = nil
    }

    func installSource(fileDescriptor: Int32) {
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: queue
        )
        newSource.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source?.data ?? []
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                closeHandle()
            }
            scheduleRead()
        }
        source = newSource
        newSource.resume()
    }

    func startTimer() {
        let newTimer = DispatchSource.makeTimerSource(queue: queue)
        newTimer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        newTimer.setEventHandler { [weak self] in
            guard let self else { return }
            readNewBytes()
        }
        timer = newTimer
        newTimer.resume()
    }

    func scheduleRead() {
        guard isReadScheduled == false else { return }
        isReadScheduled = true
        queue.asyncAfter(deadline: .now() + readDelay) { [weak self] in
            guard let self else { return }
            isReadScheduled = false
            readNewBytes()
        }
    }

    func pathIdentity() -> FileIdentity? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        return FileIdentity(device: info.st_dev, inode: info.st_ino)
    }

    func descriptorIdentity(_ descriptor: Int32) -> FileIdentity? {
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { return nil }
        return FileIdentity(device: info.st_dev, inode: info.st_ino)
    }
}
