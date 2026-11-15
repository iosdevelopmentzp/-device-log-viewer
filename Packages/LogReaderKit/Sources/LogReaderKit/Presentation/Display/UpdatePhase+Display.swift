import Foundation

public extension UpdatePhase {

    var displayName: String {
        switch self {
        case .fetching: "Getting changes"
        case .building: "Building"
        case .installing: "Installing"
        case .done: "Done"
        case .failed: "Failed"
        }
    }
}
