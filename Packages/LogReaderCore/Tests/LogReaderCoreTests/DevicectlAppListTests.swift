import Foundation
import Testing
@testable import LogReaderCore

struct DevicectlAppListTests {

    private static let json = """
    {
      "result": {
        "apps": [
          { "bundleIdentifier": "com.example.store", "name": "Store", "builtByDeveloper": false },
          { "bundleIdentifier": "com.example.chat", "name": "Chat", "builtByDeveloper": true },
          { "bundleIdentifier": "org.other.tool", "name": "Tool", "builtByDeveloper": true },
          { "bundleIdentifier": "com.example.beta", "name": "Beta", "builtByDeveloper": true },
          { "bundleIdentifier": "com.example.old" }
        ],
        "deviceIdentifier": "CCCC-WIFI"
      }
    }
    """

    @Test func decodesEveryApp() throws {
        let list = try Self.decode()
        let chat = try #require(list.apps.first { $0.bundleIdentifier == "com.example.chat" })

        #expect(list.apps.count == 5)
        #expect(chat.name == "Chat")
        #expect(chat.builtByDeveloper)
        #expect(list.apps.last?.builtByDeveloper == false)
    }

    @Test func keepsDeveloperAppsWithThePrefixSorted() throws {
        let list = try Self.decode()

        #expect(list.developerApps(rules: [DiscoveryRule(bundleIDPrefix: "com.example", logsPath: "Logs", fileExtension: "txt", fileNamePrefix: "")]).map(\.bundleIdentifier) == ["com.example.beta", "com.example.chat"])
    }

    @Test func emptyPrefixKeepsEveryDeveloperApp() throws {
        let list = try Self.decode()

        #expect(list.developerApps(rules: [DiscoveryRule(bundleIDPrefix: "", logsPath: "Logs", fileExtension: "txt", fileNamePrefix: "")]).map(\.bundleIdentifier) == ["com.example.beta", "com.example.chat", "org.other.tool"])
    }

    private static func decode() throws -> DevicectlAppList {
        try JSONDecoder().decode(DevicectlAppList.self, from: Data(json.utf8))
    }
}
