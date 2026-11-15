import Foundation

public final class FileManagerCopier {

    public init() {}
}

// MARK: - FileCopier

extension FileManagerCopier: FileCopier {

    public func copy(_ url: URL, to destination: URL, replacing: Bool) throws {
        let fileManager = FileManager.default
        if replacing, fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: url, to: destination)
    }
}
