import Foundation

public extension TimeZoneMode {

    var displayName: String {
        switch self {
        case .local: "Local"
        case .utc: "UTC"
        }
    }
}
