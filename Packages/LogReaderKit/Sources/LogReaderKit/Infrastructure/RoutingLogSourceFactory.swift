import Foundation
import LogReaderCore

public final class RoutingLogSourceFactory {

    private let fileSourceFactory: any LogSourceFactory
    private let deviceCacheRoot: URL
    private let runner: any DevicectlCommandRunning
    private let mirrorInterval: DispatchTimeInterval
    private let isDeviceAccessEnabled: @Sendable () -> Bool

    public init(
        fileSourceFactory: any LogSourceFactory,
        deviceCacheRoot: URL,
        runner: any DevicectlCommandRunning,
        mirrorInterval: DispatchTimeInterval,
        isDeviceAccessEnabled: @escaping @Sendable () -> Bool
    ) {
        self.fileSourceFactory = fileSourceFactory
        self.deviceCacheRoot = deviceCacheRoot
        self.runner = runner
        self.mirrorInterval = mirrorInterval
        self.isDeviceAccessEnabled = isDeviceAccessEnabled
    }
}

// MARK: - LogSourceFactory

extension RoutingLogSourceFactory: LogSourceFactory {

    public func makeSource(for url: URL, profile: LogProfile) -> any LogSource {
        let cacheSource = fileSourceFactory.makeSource(for: url, profile: profile)
        guard let location = DeviceFileLocation.location(of: url, in: deviceCacheRoot) else { return cacheSource }
        let mirror = DeviceFileMirror(
            location: location,
            logsPath: profile.discovery?.logsPath ?? DiscoveryRule.standardLogsPath,
            cacheURL: url,
            runner: runner,
            interval: mirrorInterval,
            isEnabled: isDeviceAccessEnabled
        )
        return DeviceLogSource(url: url, mirror: mirror, cacheSource: cacheSource)
    }
}
