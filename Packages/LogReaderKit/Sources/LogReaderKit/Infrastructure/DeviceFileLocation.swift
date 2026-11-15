import Foundation

struct DeviceFileLocation: Hashable, Sendable {
    let udid: String
    let bundleID: String
    let fileName: String

    static func deviceFolderURL(in cacheRoot: URL, udid: String) -> URL {
        cacheRoot.appendingPathComponent(udid, isDirectory: true)
    }

    static func logsURL(in cacheRoot: URL, udid: String, bundleID: String) -> URL {
        deviceFolderURL(in: cacheRoot, udid: udid).appendingPathComponent(bundleID, isDirectory: true)
    }

    static func location(of url: URL, in cacheRoot: URL) -> DeviceFileLocation? {
        let rootComponents = cacheRoot.standardized.pathComponents
        let components = url.standardized.pathComponents
        guard components.count == rootComponents.count + 3,
              Array(components.prefix(rootComponents.count)) == rootComponents else { return nil }
        let parts = components.suffix(3).map { $0 }
        return DeviceFileLocation(udid: parts[0], bundleID: parts[1], fileName: parts[2])
    }
}
