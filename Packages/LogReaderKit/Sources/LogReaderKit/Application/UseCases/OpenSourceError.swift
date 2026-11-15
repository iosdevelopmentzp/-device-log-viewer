import Foundation

public enum OpenSourceError: LocalizedError {
    case noSource
    case noProjectRoot
    case fileNotFound(fileName: String, root: URL)
    case openFailed(any Error)

    public var errorDescription: String? {
        switch self {
        case .noSource:
            "This entry has no source file."
        case .noProjectRoot:
            "Add the project folder in Settings → Projects."
        case let .fileNotFound(fileName, root):
            "\(fileName) was not found under \((root.path as NSString).abbreviatingWithTildeInPath)"
        case let .openFailed(underlying):
            "Could not open the file in the editor. \(underlying.localizedDescription)"
        }
    }
}
