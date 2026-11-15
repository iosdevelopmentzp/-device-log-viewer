import Foundation

public struct AppLogContainer: Identifiable, Hashable, Sendable {
    public let bundleID: String
    public let logsURL: URL
    public let files: [LogFileItem]

    public var id: String { logsURL.path }

    public init(bundleID: String, logsURL: URL, files: [LogFileItem]) {
        self.bundleID = bundleID
        self.logsURL = logsURL
        self.files = files
    }
}
