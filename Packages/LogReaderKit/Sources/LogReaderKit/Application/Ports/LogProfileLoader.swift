import Foundation

public protocol LogProfileLoader: Sendable {
    func load(projectRoot: URL) -> ProfileLoadResult
    func modificationDate(projectRoot: URL) -> Date?
    func writeExample(projectRoot: URL) throws
}
