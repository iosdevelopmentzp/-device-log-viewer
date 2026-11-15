import Foundation

public enum ExportFormat: Sendable, CaseIterable {
    case log
    case json

    public var fileExtension: String {
        switch self {
        case .log: "txt"
        case .json: "json"
        }
    }
}
