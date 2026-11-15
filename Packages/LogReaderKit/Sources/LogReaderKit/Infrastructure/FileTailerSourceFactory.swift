import Foundation
import LogReaderCore

public final class FileTailerSourceFactory {

    private let readDelay: DispatchTimeInterval
    private let pollInterval: DispatchTimeInterval

    public init(readDelay: DispatchTimeInterval, pollInterval: DispatchTimeInterval) {
        self.readDelay = readDelay
        self.pollInterval = pollInterval
    }
}

// MARK: - LogSourceFactory

extension FileTailerSourceFactory: LogSourceFactory {

    public func makeSource(for url: URL, profile: LogProfile) -> any LogSource {
        LogFileTailer(url: url, profile: profile, readDelay: readDelay, pollInterval: pollInterval)
    }
}
