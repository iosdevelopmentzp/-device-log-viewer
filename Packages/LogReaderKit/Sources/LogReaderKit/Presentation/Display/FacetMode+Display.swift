import Foundation
import LogReaderCore

public extension FacetMode {

    var displayName: String {
        switch self {
        case .include: "Show only checked"
        case .exclude: "Hide checked"
        }
    }
}
