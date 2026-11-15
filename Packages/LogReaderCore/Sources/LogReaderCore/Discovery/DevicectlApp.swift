import Foundation

public struct DevicectlApp: Decodable, Hashable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case name
        case builtByDeveloper
    }

    public let bundleIdentifier: String
    public let name: String
    public let builtByDeveloper: Bool

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.builtByDeveloper = try container.decodeIfPresent(Bool.self, forKey: .builtByDeveloper) ?? false
    }
}
