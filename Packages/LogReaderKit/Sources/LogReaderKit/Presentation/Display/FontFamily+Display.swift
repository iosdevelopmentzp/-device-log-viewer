import Foundation

public extension FontFamily {

    var displayName: String {
        switch self {
        case .monospaced: "Monospaced"
        case .system: "System"
        }
    }
}
