import Foundation

public struct DevicectlFileList: Decodable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case result
    }

    private enum ResultKeys: String, CodingKey {
        case files
    }

    public let files: [DevicectlFile]

    public init(from decoder: any Decoder) throws {
        let result = try decoder.container(keyedBy: CodingKeys.self).nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
        self.files = try result.decodeIfPresent([DevicectlFile].self, forKey: .files) ?? []
    }

    public func logFiles(rule: DiscoveryRule) -> [DevicectlFile] {
        let folderPrefix = Self.lastFolder(of: rule.logsPath) + "/"
        return files
            .filter { file in
                file.isDirectory == false
                    && file.relativePath.hasPrefix(folderPrefix)
                    && file.relativePath.dropFirst(folderPrefix.count).contains("/") == false
                    && rule.matches(fileName: file.name)
            }
            .sorted { $0.createdAt(fileNamePrefix: rule.fileNamePrefix) > $1.createdAt(fileNamePrefix: rule.fileNamePrefix) }
    }

    public static func lastFolder(of logsPath: String) -> String {
        logsPath.split(separator: "/").last.map(String.init) ?? logsPath
    }

    public static func parentFolder(of logsPath: String) -> String {
        logsPath.split(separator: "/").dropLast().joined(separator: "/")
    }
}
