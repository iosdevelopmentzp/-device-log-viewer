import Foundation
import LogReaderCore

final class DeviceLogSource: Sendable {

    let url: URL

    private let mirror: DeviceFileMirror
    private let cacheSource: any LogSource

    init(url: URL, mirror: DeviceFileMirror, cacheSource: any LogSource) {
        self.url = url
        self.mirror = mirror
        self.cacheSource = cacheSource
    }
}

// MARK: - LogSource

extension DeviceLogSource: LogSource {

    func events() -> AsyncStream<LogSourceEvent> {
        let mirror = mirror
        let cacheSource = cacheSource
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let forwarding = Task {
                await withCheckedContinuation { (firstAttempt: CheckedContinuation<Void, Never>) in
                    mirror.start { firstAttempt.resume() }
                }
                guard Task.isCancelled == false else {
                    continuation.finish()
                    return
                }
                for await event in cacheSource.events() {
                    continuation.yield(event)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                forwarding.cancel()
                mirror.stop()
                cacheSource.stop()
            }
        }
    }

    func stop() {
        mirror.stop()
        cacheSource.stop()
    }
}
