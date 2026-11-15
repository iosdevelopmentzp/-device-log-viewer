import Foundation

public extension ExportFormat {

    var displayName: String {
        switch self {
        case .log: "Log file"
        case .json: "JSON"
        }
    }
}
