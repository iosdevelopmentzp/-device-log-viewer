import Foundation

public struct DevicectlAppList: Decodable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case result
    }

    private enum ResultKeys: String, CodingKey {
        case apps
    }

    public let apps: [DevicectlApp]

    public init(from decoder: any Decoder) throws {
        let result = try decoder.container(keyedBy: CodingKeys.self).nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
        self.apps = try result.decodeIfPresent([DevicectlApp].self, forKey: .apps) ?? []
    }

    public func developerApps(rules: [DiscoveryRule]) -> [DevicectlApp] {
        apps
            .filter { app in app.builtByDeveloper && rules.contains { $0.matches(bundleID: app.bundleIdentifier) } }
            .sorted { $0.bundleIdentifier < $1.bundleIdentifier }
    }
}
