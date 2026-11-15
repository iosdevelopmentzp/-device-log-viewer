import Foundation

public struct DiscoveryRule: Codable, Sendable, Equatable {

    public var bundleIDPrefix: String
    public var logsPath: String
    public var fileExtension: String
    public var fileNamePrefix: String

    public static let standardLogsPath = "Library/Application Support/Logs"

    public init(bundleIDPrefix: String, logsPath: String, fileExtension: String, fileNamePrefix: String) {
        self.bundleIDPrefix = bundleIDPrefix
        self.logsPath = logsPath
        self.fileExtension = fileExtension
        self.fileNamePrefix = fileNamePrefix
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIDPrefix = try container.decodeIfPresent(String.self, forKey: .bundleIDPrefix) ?? ""
        self.logsPath = try container.decodeIfPresent(String.self, forKey: .logsPath) ?? Self.standardLogsPath
        self.fileExtension = try container.decodeIfPresent(String.self, forKey: .fileExtension) ?? ""
        self.fileNamePrefix = try container.decodeIfPresent(String.self, forKey: .fileNamePrefix) ?? ""
    }

    public func matches(bundleID: String) -> Bool {
        bundleIDPrefix.isEmpty || bundleID.hasPrefix(bundleIDPrefix)
    }

    public func matches(fileName: String) -> Bool {
        guard fileName.hasPrefix(fileNamePrefix) else { return false }
        guard fileExtension.isEmpty == false else { return true }
        return fileName.hasSuffix("." + fileExtension)
    }
}
