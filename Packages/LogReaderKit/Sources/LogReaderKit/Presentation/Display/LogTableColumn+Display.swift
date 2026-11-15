import Foundation
import LogReaderCore

public extension LogTableColumn {

    func displayName(in profile: LogProfile) -> String {
        switch self {
        case .number: "#"
        case .time: "Time"
        case .delta: "Δ"
        case .level: "Level"
        case .message: "Message"
        default: attributeID.flatMap(profile.attribute(id:))?.title ?? rawValue
        }
    }
}
