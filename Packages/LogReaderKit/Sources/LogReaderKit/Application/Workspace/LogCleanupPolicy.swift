import Foundation
import LogReaderCore

public enum LogCleanupPolicy {

    public static func olderFiles(of app: AppLogContainer) -> [URL] {
        guard let newest = app.files.max(by: { $0.createdAt < $1.createdAt }) else { return [] }
        return app.files
            .filter { $0.id != newest.id }
            .map(\.url)
    }

    public static func allFiles(of app: AppLogContainer) -> [URL] {
        app.files.map(\.url)
    }

    public static func allFiles(of device: SimulatorDevice) -> [URL] {
        device.apps.flatMap(allFiles(of:))
    }
}
