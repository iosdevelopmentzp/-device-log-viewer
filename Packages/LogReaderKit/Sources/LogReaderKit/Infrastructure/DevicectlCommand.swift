import Foundation
import LogReaderCore

enum DevicectlCommand {

    private static let domainType = "appDataContainer"

    static func listDevices() -> [String] {
        ["list", "devices"]
    }

    static func apps(device: String) -> [String] {
        ["device", "info", "apps", "--device", device]
    }

    static func files(device: String, bundleID: String, logsPath: String) -> [String] {
        // devicectl (Xcode 26.6) cuts the first characters of every name when --subdirectory points at the logs folder itself.
        var arguments = [
            "device", "info", "files",
            "--device", device,
            "--domain-type", domainType,
            "--domain-identifier", bundleID
        ]
        let parent = DevicectlFileList.parentFolder(of: logsPath)
        if parent.isEmpty == false {
            arguments += ["--subdirectory", parent]
        }
        return arguments
    }

    static func copy(device: String, bundleID: String, logsPath: String, fileName: String, destination: URL) -> [String] {
        [
            "device", "copy", "from",
            "--device", device,
            "--domain-type", domainType,
            "--domain-identifier", bundleID,
            "--source", "\(logsPath)/\(fileName)",
            "--destination", destination.path
        ]
    }
}
