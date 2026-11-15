import Foundation

enum DevicectlFixtures {

    struct Device {
        let identifier: String
        let name: String
        let osVersion: String
        let platform: String
        let tunnelState: String
        let transportType: String?
    }

    static let listCommand = "list devices"
    static let appsCommand = "device info apps"
    static let filesCommand = "device info files"
    static let copyCommand = "device copy from"

    static func devices(_ devices: [Device]) -> String {
        let items = devices.map { device in
            let transport = device.transportType.map { #", "transportType": "\#($0)""# } ?? ""
            return """
            {
              "identifier": "\(device.identifier)",
              "connectionProperties": { "tunnelState": "\(device.tunnelState)"\(transport) },
              "deviceProperties": { "name": "\(device.name)", "osVersionNumber": "\(device.osVersion)" },
              "hardwareProperties": { "platform": "\(device.platform)", "marketingName": "Test Model" }
            }
            """
        }
        return #"{ "result": { "devices": [\#(items.joined(separator: ","))] } }"#
    }

    static func apps(_ apps: [(bundleID: String, builtByDeveloper: Bool)]) -> String {
        let items = apps.map { app in
            #"{ "bundleIdentifier": "\#(app.bundleID)", "name": "App", "builtByDeveloper": \#(app.builtByDeveloper) }"#
        }
        return #"{ "result": { "apps": [\#(items.joined(separator: ","))] } }"#
    }

    static func files(_ files: [(relativePath: String, size: Int64)]) -> String {
        let items = files.map { file in
            """
            {
              "relativePath": "\(file.relativePath)",
              "metadata": { "size": \(file.size), "lastModDate": "2026-11-07T09:35:44.000Z" },
              "resources": { "isDirectory": false }
            }
            """
        }
        return #"{ "result": { "files": [\#(items.joined(separator: ","))] } }"#
    }
}
