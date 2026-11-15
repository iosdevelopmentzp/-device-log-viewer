import Foundation

public final class FileManagerTrasher {

    public init() {}
}

// MARK: - FileTrasher

extension FileManagerTrasher: FileTrasher {

    public func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
